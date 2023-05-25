# python3 -m venv venv
# source venv/bin/activate
# pip3 install pycryptodome
# python3 init_code_hash.py
#
# to deactivate the venv: deactivate
import json
from Crypto.Hash import keccak
import binascii

filename_bytecode = 'out/UniswapV3Pool.sol/UniswapV3Pool.json'
filename_pooladdress = 'lib/v3-periphery/contracts/libraries/PoolAddress.sol'

POOL_INIT_CODE_HASH_line = 5
POOL_INIT_CODE_HASH_code = '    bytes32 internal constant POOL_INIT_CODE_HASH = 0x{kek};'

bytecode = ''
content = ''

if __name__ == '__main__':
    with open(filename_bytecode, 'r') as f:
        bytecode = bytes.fromhex(json.load(f)['bytecode']['object'][2:])
    f.close()
    
    kek = keccak.new(digest_bits = 256).update(bytecode).hexdigest()
    
    with open(filename_pooladdress, 'r') as g:
        content = g.read().splitlines()
        content[POOL_INIT_CODE_HASH_line] = POOL_INIT_CODE_HASH_code.format(kek = kek)
        
    with open(filename_pooladdress, 'w') as g:
        g.write('\n'.join(content))

    print('POOL_INIT_CODE_HASH updated to: ' + kek)
        
    g.close()