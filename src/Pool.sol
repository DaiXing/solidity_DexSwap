// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/SqrtPriceMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SwapMath.sol";
import "./libraries/FixedPoint128.sol";

import "./interfaces/IPool.sol";
import "./interfaces/IFactory.sol";

// 池子。
contract Pool is IPool {
    using SafeCast for uint256;
    using LowGasSafeMath for int256;
    using LowGasSafeMath for uint256;

    address public immutable factory; // 工厂地址
    address public immutable token0; // 币0
    address public immutable token1; // 币1
    uint24 public immutable fee; // 手续费。费率
    int24 public immutable tickLower; // tick下界
    int24 public immutable tickUpper; // tick上界
    int24 public tick; // tick。
    uint160 public sqrtPriceX96; // 价格。平方根，X96格式。
    uint128 public liquidity; // 流动性。
    uint256 public feeGrowthGlobal0X128; // token0的累计手续费。
    uint256 public feeGrowthGlobal1X128; // token1的累计手续费。

    // 使用 CREATE2 创建对象。 new Pool{salt: salt}()
    // 不能带参数。
    constructor() {
        IFactory factoryObj = IFactory(msg.sender);

        // 传递参数。
        (factory, token0, token1, tickLower, tickUpper, fee) = factoryObj
            .parameters();
    }
    // 初始化。
    function initialize(uint160 sqrtPriceX96_) public {
        require(sqrtPriceX96 == 0, "no repeat ");

        // 找tick。
        tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96_);
        // tick必须在区间。
        require(
            tick >= tickLower && tick < tickUpper,
            "tick not in [ tickLower, tickUpper ]"
        );
        // 价格。
        sqrtPriceX96 = sqrtPriceX96_;
    }

    // 寸头。仓位。
    struct Position {
        uint128 liquidity; // 流动性
        uint128 token0Owed; // 可提取的 token0 数量。本金+手续费。
        uint128 token1Owed; // 可提取的 token1 数量。本金+手续费。
        uint256 feeGrowthInside0LastX128; // 上次提取手续费时的 feeGrowthGlobal0X128
        uint256 feeGrowthInside1LastX128; // 上次提取手续费时的 feeGrowthGlobal1X128
    }

    // 全部仓位。  owner >> position  1个owner只能有1个仓位。
    mapping(address => Position) positions;

    // 查询寸头。
    function getPosition(
        address owner // 创建者。
    )
        external
        view
        returns (
            uint128 liquidity_, // 流动性
            uint256 feeGrowthInside0LastX128, // 币0，未提取的手续费
            uint256 feeGrowthInside1LastX128, // 币1，未提取的手续费
            uint128 tokensOwed0, // 币0，拥有的数量
            uint128 tokensOwed1 // 币1，拥有的数量
        )
    {
        // 1个owner只能有1个仓位。
        Position storage pos = positions[owner];
        return (
            pos.liquidity,
            pos.feeGrowthInside0LastX128,
            pos.feeGrowthInside1LastX128,
            pos.token0Owed,
            pos.token1Owed
        );
    }

    // 币铸造。
    function mint(
        address recipient, // 归属人
        uint128 amount, // 数量。
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    // 领取
    function collect(
        address recipient, // 归属人
        uint128 amount0Requested, // 币0，要求数量
        uint128 amount1Requested // 币1，要求数量
    ) external;

    // 销毁。
    function burn(
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    // 交换。交易。
    function swap(
        address recipient, // 归属人
        bool zeroForOne, // 用token0换token1 。输入、输出。
        uint256 amountSpecified, // 数量。正负
        uint160 sqrtPriceLimitX96, // 限制价格
        int24 tick // tick
    ) external;

    // 修改仓位。
    struct ModifyPositionParams {
        address owner;
        int128 liquidityDelta; // 流动性，变量。
    }
    // 修改仓位。
    function _modifyPosition(
        ModifyPositionParams memory params
    ) private returns (uint256 amount0, uint256 amount1) {
        uint160 priceLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 priceUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        // 通过新增的流动性计算 amount0 和 amount1
        amount0 = SqrtPriceMath.getAmount0Delta(
            sqrtPriceX96,
            priceUpper,
            params.liquidityDelta
        );
        amount1 = SqrtPriceMath.getAmount1Delta(
            priceLower,
            sqrtPriceX96,
            params.liquidityDelta
        );

        // 仓位。
        Position storage pos = positions[params.owner];

        // 提取手续费。增量。
        uint128 tokensOwed0 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal0X128 - pos.feeGrowthInside0LastX128, // 增量
                pos.liquidity, // 流动性
                FixedPoint128.Q128 //倍数
            )
        );
        uint128 tokensOwed1 = uint128(
            FullMath.mulDiv(
                feeGrowthGlobal1X128 - pos.feeGrowthInside1LastX128, // 增量
                pos.liquidity, // 流动性
                FixedPoint128.Q128 //倍数
            )
        );

        // 更新手续费的记录。
        pos.feeGrowthInside0LastX128 = feeGrowthGlobal0X128;
        pos.feeGrowthInside1LastX128 = feeGrowthGlobal1X128;

        // 保存手续费。
        if (tokensOwed0 > 0) {
            pos.token0Owed += tokensOwed0;
        }
        if (tokensOwed1 > 0) {
            pos.token1Owed += tokensOwed1;
        }

        // 修改流动性。
        // 池子流动性。
        liquidity = LiquidityMath.addDelta(liquidity, params.liquidityDelta);
        // 仓位流动性。
        pos.liquidity = LiquidityMath.addDelta(
            pos.liquidity,
            params.liquidityDelta
        );
    }

    // 池子拥有的token0
    function balance0() public returns (uint256) {
        (bool ok, bytes memory data) = token0.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(ok && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    // 池子拥有的token1
    function balance1() public returns (uint256) {
        (bool ok, bytes memory data) = token1.staticcall(
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(this))
        );
        require(ok && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    // 币铸造。 修改仓位的流动性。
    function mint(
        address recipient, // 归属人
        uint128 amount, // 数量。就是流动性。
        bytes calldata data
    ) public returns (uint256 amount0, uint256 amount1) {
        require(amount > 0, "amount need > 0 ");

        // 用 amount 算出需要的 amount0 amount1
        (uint256 amount0X, uint256 amount1X) = _modifyPosition(
            ModifyPositionParams({
                owner: recipient, // 找仓位。
                liquidityDelta: int128(amount) // 流动性
            })
        );
        amount0 = uint256(amount0X);
        amount1 = uint256(amount1X);

        // 当前池子拥有的 token0 token1
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) {
            balance0Before = balance0();
        }
        if (amount1 > 0) {
            balance1Before = balance1();
        }

        // 回调。
        // todo msg.sender 怎么关联 IMintCallback ？
        IMintCallback(msg.sender).mintCallback(amount0, amount1, data);

        if (amount0 > 0) {
            require(
                balance0Before.add(amount0) <= balance0(),
                "balance0 invalid"
            );
        }
        if (amount1 > 0) {
            require(
                balance1Before.add(amount1) <= balance1(),
                "balance1 invalid"
            );
        }

        emit Mint(msg.sender, recipient, amount, amount0, amount1);
    }

    // 领取
    function collect(
        address recipient, // 归属人
        uint128 amount0Requested, // 币0，要求数量
        uint128 amount1Requested // 币1，要求数量
    ) external returns (uint256 amount0, uint256 amount1) {
        // owner的仓位。
        Position storage pos = positions[msg.sender];

        // 取小值。
        amount0 = (amount0Requested > pos.token0Owed)
            ? pos.token0Owed
            : amount0Requested;
        amount1 = (amount1Requested > pos.token1Owed)
            ? pos.token1Owed
            : amount1Requested;

        // 转账。
        if (amount0 > 0) {
            pos.token0Owed -= amount0;
            TransferHelper.safeTransfer(msg.sender, recipient, amount0);
        }
        if (amount1 > 0) {
            pos.token1Owed -= amount1;
            TransferHelper.safeTransfer(msg.sender, recipient, amount1);
        }

        emit Collect(msg.sender, recipient, amount0, amount1);
    }
}
