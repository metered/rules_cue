import argparse
import json

parser = argparse.ArgumentParser(
    description='Render a JSON object')

parser.add_argument(
    '--put_value', action='append', metavar=('key', 'value'), nargs=2, default=[],
    help='Add a value to the output.')

parser.add_argument(
    '--put_json', action='append', metavar=('key', 'value'), nargs=2, default=[],
    help='Add a JSON-encoded value to the output.')

parser.add_argument(
    '--put_file', action='append', metavar=('key', 'src'), nargs=2, default=[],
    help="Add the contents of the file as a value")

parser.add_argument(
    '--output', action='store', required=True,
    help='Target path for the output.')

def main(args):
  o = dict()

  for key, value in args.put_value:
    o[key] = value

  for key, value in args.put_json:
    o[key] = json.loads(value)

  for key, file in args.put_file:
    with open(file, 'r', encoding='utf-8') as f:
      o[key] = f.read()

  with open(args.output, 'w', encoding='utf-8') as f:
    json.dump(o, f)

if __name__ == '__main__':
    main(parser.parse_args())
