// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// 头寸、仓位。
interface IPositionManager is IERC721 {
    // 头寸、仓位。
    struct PositionInfo {
        uint256 id; // 仓位ID
        address owner; // 所有者
        address token0; // 币0
        address token1; // 币1
        uint32 index; // 池子下标
        uint24 fee; // 费率
        uint128 liquidity; // 流动性
        int24 tickLower; // tick下界
        int24 tickUpper; // tick下界
        uint128 tokensOwed0; // 币0
        uint128 tokensOwed1; // 币1
        uint256 feeGrowthInside0LastX128; // 币0，增量手续费
        uint256 feeGrowthInside1LastX128; // 币1，增量手续费
    }

    // 查询全部的仓位。
    function getAllPositions() external returns (PositionInfo[] memory);

    // 铸造。
    struct MintParams {
        address token0; // 币0
        address token1; // 币1
        uint32 index; // 池子的下标。
        uint256 amount0Desired; // 币0，数量
        uint256 amount1Desired; // 币1，数量
        address recipient; // 持有人
        uint256 deadline; // 截止时间。过期了，就不执行了。
    }

    // 铸造。
    function mint(
        MintParams calldata params
    )
        external
        returns (
            uint256 positionId, // 仓位ID
            uint128 liquidity, // 流动性
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        );

    // 销毁
    function burn(
        uint256 positionId // 仓位ID
    )
        external
        returns (
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        );

    // 领取。
    function collect(
        uint256 positionId, // 仓位ID
        address recipient // 持有人
    )
        external
        returns (
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        );

    // 铸造。回调。
    function mintCallback(
        uint256 amount0, // 币0，数量
        uint256 amount1, // 币1，数量
        bytes calldata data
    ) external;
}
