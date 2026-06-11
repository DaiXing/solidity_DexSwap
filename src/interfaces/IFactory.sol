// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 池子工厂。
interface IFactory {
    // 创建池子的参数。
    struct Parameters {
        address factory; // 工厂地址
        address tokenA; // 币地址
        address tokenB; // 币地址
        int24 tickLower; // tick 下界
        int24 tickUpper; // tick 上界
        uint24 fee; // 手续费费率
    }
    // 池子创建。
    event PoolCreated(
        address token0, // 币地址
        address token1, // 币地址
        uint32 index,
        int24 tickLower, // tick 下界
        int24 tickUpper, // tick 上界
        uint24 fee, // 手续费费率
        address pool // 池子地址
    );

    // 查询参数。
    function parameters()
        external
        view
        returns (
            address factory, // 工厂地址
            address tokenA, // 币地址
            address tokenB, // 币地址
            int24 tickLower, // tick 下界
            int24 tickUpper, // tick 上界
            uint24 fee // 手续费
        );

    // 查询池子。
    function getPool(
        address tokenA, // 币地址
        address tokenB, // 币地址
        uint32 index
    ) external returns (address pool);

    // 创建池子。
    function createPool(
        address tokenA, // 币地址
        address tokenB, // 币地址
        int24 tickLower, // tick 下界
        int24 tickUpper, // tick 上界
        uint24 fee // 手续费
    ) external returns (address pool);
}
