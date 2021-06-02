import json
import sys


if __name__ == '__main__':
    with open(sys.argv[1], 'r') as file:
        configuration = json.loads(file.read())
    print(
        f'{configuration["region"]} '
        f'{configuration["timeout"]} '
        f'{configuration["instance_type"]} '
        f'{configuration["initial_instance_count"]} '
        f'{"true" if configuration["enable_data_capture"] == True else "false"} '
        f'{configuration["data_capture_s3_prefix"]} '
        f'{configuration["data_capture_sample_percent"]}'
    )
