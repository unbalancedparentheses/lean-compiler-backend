import sys,runpy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/"scripts"))
import cjson_benchmark
cjson_benchmark.ROOT=Path('/Users/unbalancedparen/projects/lean-compiler-backend')
helper=sys.argv.pop(1)
runpy.run_path(helper,run_name="__main__")
