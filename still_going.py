import random 

lst_test_set = [random.randint(1, 101) for i in range(1, 101)]

def even_numbers(lst_test_set):
    for lst_ele in lst_test_set:
        if lst_ele % 2 == 0:
            print(f"{lst_ele} is an even number")

even_numbers(lst_test_set)