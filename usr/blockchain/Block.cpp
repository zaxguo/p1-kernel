// #include <klib.h>
// #include <klib-macros.h>
#include "stdio.h"
#include "string.h"
#include "vos.h"

#include "Block.h"
#include "sha256.h"

// "sDataIn": string to add a bit randomness to hash input string
void Block::block_init(uint32_t nIndexIn, const char *sDataIn, const char *sPrevHashIn) {
    _nIndex = nIndexIn;
    _sData = sDataIn;
    _sPrevHash = sPrevHashIn;
    _nNonce = -1;
    _tTime = uptime_ms()/1000;
}

const char *Block::GetHash() {
    return _sHash;
}

// search for a nouce value, so that the computed hash (as string) matches
// "diffStr"
void Block::MineBlock(const char *diffStr) {
    int nDifficulty = strlen(diffStr);
    do {
        _nNonce++;
        _CalculateHash(_sHash);
    } while (memcmp(_sHash, diffStr, nDifficulty) != 0);

    printf("Block mined:%s\n", _sHash);
}

inline void Block::_CalculateHash(char *buf) {
    static char str[1024];
	// str: input to hash, with added randomness (e.g. time) & prev hash
    sprintf(str, "%d%d%s%d%s", _nIndex, _tTime, _sData, _nNonce, _sPrevHash);
	// hash twice
    sha256(buf, str);
    sha256(buf, buf);
}