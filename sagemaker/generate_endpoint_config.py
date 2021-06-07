import sys
import json


if __name__ == '__main__':
    production_variants = [{
        "VariantName": sys.argv[1],
        "ModelName": sys.argv[1],
        "InitialInstanceCount": int(sys.argv[2]),
        "InstanceType": sys.argv[3]
    }]
    print(json.dumps(production_variants))
