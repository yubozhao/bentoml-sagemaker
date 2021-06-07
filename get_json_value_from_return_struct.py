import json
import sys

if __name__ == '__main__':
    json_result = json.loads(sys.stdin.read())

    if len(sys.argv) == 1:
        print(json_result)
    elif len(sys.argv) == 2:
        keys = sys.argv[1].split('.')
        result = json_result
        for key in keys:
            result = result[key]
        print(result)
    else:
        result_list = []
        for arg in sys.argv[1:]:
            keys = arg.split('.')
            result = json_result
            for key in keys:
                result = result[key]
            result_list.append(result)
        print((' ').join(result_list))
