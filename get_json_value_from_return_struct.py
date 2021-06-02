import json
import sys

if __name__ == '__main__':
    json_result = json.loads(sys.stdin.read())

    if len(sys.argv) == 1:
        print(json_result)
    else:
        keys = sys.argv[1].split('.')
        result = json_result
        for key in keys:
            result = result[key]
        print(result)
