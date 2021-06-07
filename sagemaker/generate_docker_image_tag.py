import sys


if __name__ == '__main__':
    image_tag = f'{sys.argv[2]}-{sys.argv[3]}'.lower()
    print(f"{sys.argv[1]}:{image_tag}")
