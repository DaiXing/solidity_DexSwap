// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/LiquidityAmounts.sol";
import "./libraries/TickMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPositionManager.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolManager.sol";

// 寸头。仓位。
contract PositionManager is IPositionManager, IERC721 {
    // 池子管理器。
    IPoolManager public poolManager;
    // ID 从1 开始。
    uint256 private _nextId = 1;
    // 仓位。
    mapping(uint256 => PositionInfo) positions;

    constructor(
        address poolManager_
    ) IERC721("PositionManager", "PositionManager") {
        poolManager = IPoolManager(poolManager_);
    }

    // 查询全部的仓位。
    function getAllPositions() external returns (PositionInfo[] memory) {
        // 数量。
        uint256 size = _nextId - 1;

        PositionInfo[] memory posList = new PositionInfo[](size);
        for (uint256 m = 0; m < size; m++) {
            // positions 没有使用 0 。所以加1 。
            posList[m] = positions[m + 1];
        }
        return posList;
    }

    modifier checkDeadline(uint256 deadline) {
        require(deadline >= block.timestamp, "deadline invalid");
    }
    // 铸造。
    function mint(
        MintParams calldata params
    )
        external
        checkDeadline(params.deadline)
        returns (
            uint256 positionId, // 仓位ID
            uint128 liquidity, // 流动性
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        )
    {
        poolManager.getPool(params.token0, params.token1, params.index);
    }
}
