# Lambda itself

data "archive_file" "ingestion_lambda" {
  type        = "zip"
  output_path = "${path.module}/../packages/ingestion/function.zip"
  source_file = "${path.module}/../src/lambda_ingest.py"
}

resource "aws_s3_object" "lambda_code" {
bucket = aws_s3_bucket.code_bucket.bucket
  key    = "ingestion/function.zip"
  source = data.archive_file.ingestion_lambda.output_path
  etag   = filemd5(data.archive_file.ingestion_lambda.output_path)
}

resource "aws_lambda_function" "ingestion_handler" {
  function_name    = "ingestion_handler"
  s3_bucket        = aws_s3_bucket.code_bucket.bucket
  s3_key           = aws_s3_object.lambda_code.key
  source_code_hash = data.archive_file.ingestion_lambda.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  layers           = [aws_lambda_layer_version.helper_lambda_layer.arn]
  handler          = "lambda_ingest.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      BUCKET_NAME = data.aws_s3_bucket.s3_ingestion_bucket.bucket
    }
  }
}


# Associated Lambda Layer

resource "null_resource" "prepare_layer_files" {
  triggers = {
    
    helper_file_hash_1 = filebase64sha256("${path.module}/../src/ingestion_utils/database_utils.py")
    helper_file_hash_2 = filebase64sha256("${path.module}/../src/ingestion_utils/file_utils.py")
    helper_file_hash_3 = filebase64sha256("${path.module}/../src/helpers.py")
    
}

  provisioner "local-exec" {
    command = <<EOT
    LAYER_PATH="${path.module}/../packages/ingestion/layer/python/lib/python3.12/site-packages"
      mkdir -p "$LAYER_PATH"
      mkdir -p "$LAYER_PATH/ingestion_utils"
      cp "${path.module}/../src/helpers.py" "$LAYER_PATH/helpers.py"
      cp "${path.module}/../src/ingestion_utils/database_utils.py" "$LAYER_PATH/ingestion_utils/database_utils.py"
      cp "${path.module}/../src/ingestion_utils/file_utils.py" "$LAYER_PATH/ingestion_utils/file_utils.py"

      pip install --no-cache-dir pg8000 --target "$LAYER_PATH"
    EOT
  }
}

data "archive_file" "helper_lambda_layer" {
  type        = "zip"
  output_path = "${path.module}/../packages/ingestion/helpers.zip"
  source_dir = "${path.module}/../packages/ingestion/layer"
  depends_on = [ null_resource.prepare_layer_files ]
}

resource "aws_s3_object" "helper_layer_code" {
bucket = aws_s3_bucket.code_bucket.bucket
  key    = "ingestion/helpers.zip"
  source = data.archive_file.helper_lambda_layer.output_path
  #etag   = filemd5(data.archive_file.helper_lambda_layer.output_path)
  depends_on = [ null_resource.prepare_layer_files ]
}

resource "aws_lambda_layer_version" "helper_lambda_layer" {
  layer_name          = "helpers-layer" 
  s3_bucket           = aws_s3_bucket.code_bucket.id
  s3_key              = aws_s3_object.helper_layer_code.key
  s3_object_version   = aws_s3_object.helper_layer_code.version_id
}