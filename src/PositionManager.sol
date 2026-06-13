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
contract PositionManager is IPositionManager, ERC721 {
    // 池子管理器。
    IPoolManager public poolManager;
    // ID 从1 开始。
    uint256 private _nextId = 1;
    // 仓位。
    mapping(uint256 => PositionInfo) positions;

    constructor(
        address poolManager_
    ) ERC721("PositionManager", "PositionManager") {
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
        // 池子。
        address poolAddr = poolManager.getPool(
            params.token0,
            params.token1,
            params.index
        );
        IPool pool = IPool(poolAddr);

        // 价格。
        uint160 sqrtPriceX96 = pool.sqrtPriceX96();
        uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(pool.tickLower());
        uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(pool.tickUpper());

        // 用 价格、数量，得到 流动性
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            params.amount0Desired,
            params.amount1Desired
        );

        // 回调。 包装数据。
        bytes memory data = abi.encode(
            params.token0,
            params.token1,
            params.index,
            msg.sender
        );

        // 铸造。
        // todo 确定用 address(this) ？ 多个用户的流动性，混合在一起？
        (amount0, amount1) = pool.mint(address(this), liquidity, data);

        // ID
        positionId = _nextId;
        _nextId++;

        // 给用户 NFT
        _mint(params.recipient, positionId);

        // 查询仓位。
        (
            uint128 liquidity, // 流动性
            uint256 feeGrowthInside0LastX128, // 币0，未提取的手续费
            uint256 feeGrowthInside1LastX128, // 币1，未提取的手续费
            uint128 tokensOwed0, // 币0，拥有的数量
            uint128 tokensOwed1 // 币1，拥有的数量
        ) = pool.getPosition(address(this));

        // 头寸。
        positions[positionId] = PositionInfo({
            id: positionId,
            owner: params.recipient,
            token0: params.token0,
            token1: params.token1,
            index: params.index,
            fee: pool.fee(),
            liquidity: liquidity,
            tickLower: pool.tickLower(),
            tickUpper: pool.tickUpper(),
            tokensOwed0: 0,
            tokensOwed1: 0,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128
        });
    }

    // 铸造。回调。
    function mintCallback(
        uint256 amount0, // 币0，数量
        uint256 amount1, // 币1，数量
        bytes calldata data
    ) external {
        // 解码。
        (address token0, address token1, uint32 index, address payer) = abi
            .decode(data, (address, address, uint32, address));

        // 池子
        address poolAddr = poolManager.getPool(token0, token1, index);
        IPool pool = IPool(poolAddr);

        // 池子调过来的。
        require(poolAddr == msg.sender, "caller is not pool");

        // 转账，给池子。
        if (amount0 > 0) {
            IERC20(token0).transferFrom(payer, poolAddr, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(payer, poolAddr, amount1);
        }
    }

    modifier isAuthorizedForToken(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        require(_isAuthorized(owner, msg.sender, tokenId), "Not approved");
        _;
    }

    // 销毁
    function burn(
        uint256 positionId // 仓位ID
    )
        external
        isAuthorizedForToken(positionId)
        returns (
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        )
    {
        // 头寸
        PositionInfo storage pos = positions[positionId];
        uint128 liquidity = pos.liquidity;

        // 池子
        address poolAddr = poolManager.getPool(
            pos.token0,
            pos.token1,
            pos.index
        );
        IPool pool = IPool(poolAddr);

        // 销毁。 pos的流动性。
        (amount0, amount1) = pool.burn(liquidity);

        // 累加数量。
        pos.tokensOwed0 += amount0;
        pos.tokensOwed1 += amount1;

        // 流动性，对应的手续费。
        (
            ,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            ,

        ) = pool.getPosition(address(this));

        // 累加手续费。
        pos.tokensOwed0 += FullMath.mulDiv(
            feeGrowthInside0LastX128 - pos.feeGrowthInside0LastX128,
            liquidity,
            FixedPoint128.Q128
        );
        pos.tokensOwed1 += FullMath.mulDiv(
            feeGrowthInside1LastX128 - pos.feeGrowthInside1LastX128,
            liquidity,
            FixedPoint128.Q128
        );

        // 更新信息。
        pos.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        pos.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
        pos.liquidity = 0;
    }

    // 领取。
    function collect(
        uint256 positionId, // 仓位ID
        address recipient // 持有人
    )
        external
        isAuthorizedForToken(positionId)
        returns (
            uint256 amount0, // 币0，数量
            uint256 amount1 // 币1，数量
        )
    {
        // 头寸
        PositionInfo storage pos = positions[positionId];
        uint128 liquidity = pos.liquidity;

        // 池子
        address poolAddr = poolManager.getPool(
            pos.token0,
            pos.token1,
            pos.index
        );
        IPool pool = IPool(poolAddr);

        // 全部领取。
        (amount0, amount1) = pool.collect(
            recipient,
            pos.tokensOwed0,
            pos.tokensOwed1
        );

        // 更新信息。
        pos.tokensOwed0 = 0;
        pos.tokensOwed1 = 0;

        // todo 彻底清理？
        if (pos.liquidity == 0) {
            _burn(positionId);
        }
    }
}
