// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPool {
    // 工厂地址
    function factory() external returns (address pool);
    // 币0
    function token0() external returns (address);
    // 币1
    function token1() external returns (address);
    // 手续费。费率
    function fee() external returns (uint24);
    // tick下界
    function tickLower() external returns (int24);
    // tick上界
    function tickUpper() external returns (int24);
    // tick。
    function tick() external returns (int24);
    // 价格。平方根，X96格式。
    function sqrtPriceX96() external returns (uint160);
    // 流动性。
    function liquidity() external returns (uint128);
    // 初始化。
    function initialize(uint160 sqrtPriceX96) external;
    // token0的累计手续费。
    function feeGrowthGlobal0X128() external returns (uint256);
    // token1的累计手续费。
    function feeGrowthGlobal1X128() external returns (uint256);

    // 查询寸头。
    function getPosition(
        address owner
    )
        external
        view
        returns (
            uint128 liquidity, // 流动性
            uint256 feeGrowthInside0LastX128, // 币0，未提取的手续费
            uint256 feeGrowthInside1LastX128, // 币1，未提取的手续费
            uint128 tokensOwed0, // 币0，拥有的数量
            uint128 tokensOwed1 // 币1，拥有的数量
        );

    // 币铸造。
    event Mint(
        address sender,
        address indexed owner, // 币的所有者。
        uint128 amount, // 总量。
        uint256 amount0, // token0 数量
        uint256 amount1 // token1 数量
    );

    // 币铸造。 recipient 就是owner
    function mint(
        address recipient, // 归属人
        uint128 amount, // 数量。 流动性。
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    // 领取
    event Collect(
        address indexed owner,
        address recipient, // 归属人
        uint128 amount0, // 币0，数量
        uint128 amount1 // 币1，数量
    );

    // 领取 。 recipient 是to 。 owner 把币给 recipient 。
    function collect(
        address recipient, // 归属人
        uint128 amount0Requested, // 币0，要求数量
        uint128 amount1Requested // 币1，要求数量
    ) external returns (uint256 amount0, uint256 amount1);

    // 销毁。
    event Burn(
        address indexed owner, // 币的所有者。
        uint128 amount, // 数量。 流动性。
        uint256 amount0, // 币0，数量
        uint256 amount1 // 币1，数量
    );

    // 销毁。
    function burn(
        uint128 amount // 数量。 流动性。
    ) external returns (uint256 amount0, uint256 amount1);

    // 交换。交易。
    event Swap(
        address indexed sender,
        address recipient, // 归属人
        uint256 amount0, // 币0
        uint256 amount1, // 币1
        uint160 sqrtPriceX96, // 价格
        uint128 liquidity, // 流动性
        int24 tick // tick
    );
    // 交换。交易。
    function swap(
        address recipient, // 归属人
        bool zeroForOne, // 用token0换token1 。输入、输出。
        uint256 amountSpecified, // 数量。正负
        uint160 sqrtPriceLimitX96, // 限制价格
        int24 tick // tick
    ) external returns (int256 amount0, int256 amount1);
}

// 铸造的回调
interface IMintCallback {
    function mintCallback(
        uint256 amount0Owed, // 币0的数量。给与
        uint256 amount1Owed, // 币1的数量。给与
        bytes calldata data // 数据
    ) external;
}

// 交换的回调
interface ISwapCallback {
    function swapCallback(
        uint256 amount0Delta, // 币0的数量。变化量
        uint256 amount1Delta, // 币1的数量。变化量
        bytes calldata data // 数据
    ) external;
}
