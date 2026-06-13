// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./interfaces/IPoolManager.sol";
import "./Factory.sol";
import "./interfaces/IPool.sol";

contract PoolManager is IPoolManager, Factory {
    // 配对。 token0 token1
    Pair[] public pairs;

    // 查询配对。
    function getPairs() external returns (Pair[] memory pairs) {
        return pairs;
    }

    // 查询池子。
    function getAllPools() external returns (PoolInfo[] memory poolInfos) {
        uint32 poolCount = 0;

        // 算pool的数量。
        uint256 len = pairs.length;
        for (uint256 k = 0; k < len; k++) {
            Pair storage pair = pairs[k];
            // 1个配对，有很多池子。
            poolCount += uint32(pools[pair.token0][pair.token1].length);
        }

        // 数组。
        poolInfos = new PoolInfo[](poolCount);

        // 遍历明细。
        uint256 poolIndex = 0;
        uint256 len = pairs.length;
        for (uint256 k = 0; k < len; k++) {
            Pair storage pair = pairs[k];
            // 1个配对，有很多池子。
            address[] memory addrList = pools[pair.token0][pair.token1];

            uint256 len2 = addrList.length;
            for (uint256 m = 0; m < len2; m++) {
                IPool pool = IPool(addrList[m]);

                // 一个池子。
                poolInfos[poolIndex] = PoolInfo({
                    pool: addrList[m],
                    token0: pair.token0,
                    token1: pair.token1,
                    index: m,
                    fee: pool.fee(),
                    feeProtocol: 0,
                    tickLower: pool.tickLower(),
                    tickUpper: pool.tickUpper(),
                    sqrtPriceX96: pool.sqrtPriceX96(),
                    liquidity: pool.liquidity()
                });

                poolIndex++;
            }
        }
    }

    // 如果需要，就创建、初始化池子。
    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable returns (address poolAddr) {
        require(params.token0 < params.token1, "token0 must < token1 ");

        // 创建池子。如果有，就复用。
        poolAddr = createPool(
            params.token0,
            params.token1,
            params.tickLower,
            params.tickUpper,
            params.fee
        );

        uint256 poolSize = pools[token0][token1].length;
        IPool pool = IPool(poolAddr);

        // 新池子，没有初始化价格。
        if (pool.sqrtPriceX96() == 0) {
            // 初始化价格。
            pool.initialize(params.sqrtPriceX96);

            // 这个列表的首个池子。
            if (poolSize == 1) {
                pairs.push(
                    Pair({token0: params.token0, token1: params.token1})
                );
            }
        }
    }
}
