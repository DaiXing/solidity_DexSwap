// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 池子过滤器。继承工厂。
interface IPoolManager is IFactory {
    // 池子信息。
    struct PoolInfo {
        address pool; // 池子地址
        address token0; // 币0地址
        address token1; // 币1地址
        uint32 index; // 列表的下标。
        uint24 fee; // 费率
        uint8 feeProtocol; // 费率协议
        int24 tickLower; // tick下界
        int24 tickUpper; // tick上界
        int24 tick; // tick
        uint160 sqrtPriceX96; // 价格。
        uint128 liquidity; // 流动性
    }

    // 配对。
    struct Pair {
        address token0; // 币0地址
        address token1; // 币1地址
    }

    // 查询配对。
    function getPairs() external returns (Pair[] memory pairs);

    // 查询池子。
    function getAllPools() external returns (PoolInfo[] memory);

    // 创建、初始化。
    struct CreateAndInitializeParams {
        address token0; // 币0地址
        address token1; // 币1地址
        uint24 fee; // 费率
        int24 tickLower; // tick下界
        int24 tickUpper; // tick上界
        uint160 sqrtPriceX96; // 价格。
    }

    // 如果需要，就创建、初始化池子。
    function createAndInitializePoolIfNecessary(
        CreateAndInitializeParams calldata params
    ) external payable returns (address pool);
}
