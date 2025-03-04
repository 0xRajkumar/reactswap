## ReactSwap AMM V1

Based on Uniswap V2 with liquidity migration features by SushiSwap.

Code from [Uniswap V2](https://github.com/Uniswap/uniswap-v2-core/tree/27f6354bae6685612c182c3bc7577e61bc8717e3/contracts) with the following modifications.

1. Change contract version to 0.8.2 and do the necessary patching.
2. Add `migrator` member in `UniswapV2Factory` which can be set by `feeToSetter`.
3. Allow `migrator` to specify the amount of `liquidity` during the first mint. Disallow first mint if migrator is set.
4. Rename contracts.
