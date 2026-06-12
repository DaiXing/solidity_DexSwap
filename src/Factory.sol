// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IFactory.sol";
import "./interfaces/IPool.sol";
import "./Pool.sol";

// pool的工厂。
contract Factory is IFactory {
    // 全部的池子。 token0 >> token1 >> poolIndex
    mapping(address => mapping(address => address[])) pools;

    // 参数。 临时。 透传参数给pool实例。
    Parameters public override parameters;

    // 排序。 小 > 大
    function sortToken(
        address tokenA,
        address tokenB
    ) private pure returns (address, address) {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    // 检测token
    modifier tokenValid(address tokenA, address tokenB) {
        require(tokenA != tokenB, "token addr equal");
        require(
            tokenA != address(0) && tokenB != address(0),
            "token addr zero"
        );
        _;
    }

    // 创建池子。
    function createPool(
        address tokenA, // 币地址
        address tokenB, // 币地址
        int24 tickLower, // tick 下界
        int24 tickUpper, // tick 上界
        uint24 fee // 手续费
    ) public tokenValid(tokenA, tokenB) returns (address) {
        // 排序
        (address token0, address token1) = sortToken(tokenA, tokenB);

        // 检查已有的池子。
        address[] memory poolList = pools[token0][token1];

        for (uint256 index = 0; index < poolList.length; index++) {
            address poolAddr = poolList[index];
            IPool pool = IPool(poolAddr);

            // 价格区间，手续费。
            if (
                pool.tickLower() == tickLower &&
                pool.tickUpper() == tickUpper &&
                pool.fee() == fee
            ) {
                return poolAddr;
            }
        }

        // 保存参数。
        parameters = Parameters(
            address(this),
            token0,
            token1,
            tickLower,
            tickUpper,
            fee
        );

        // 加盐。
        bytes32 salt = keccak256(
            abi.encode(token0, token1, tickLower, tickUpper, fee)
        );

        // 创建池子。
        address addr = address(new Pool{salt: salt}());

        // 放入集合。
        pools[token0][token1].push(addr);

        // 下标。
        uint256 index2 = pools[token0][token1].length - 1;
        uint32 index3 = uint32(index2);

        // 删除参数。
        delete parameters;

        emit PoolCreated(
            token0,
            token1,
            index3,
            tickLower,
            tickUpper,
            fee,
            addr
        );

        return addr;
    }

    // 查询池子。
    function getPool(
        address tokenA,
        address tokenB,
        uint32 index
    ) public view tokenValid(tokenA, tokenB) returns (address) {
        // 排序
        (address token0, address token1) = sortToken(tokenA, tokenB);
        // 集合
        address pool = pools[token0][token1][index];
        return pool;
    }
}
