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
}
