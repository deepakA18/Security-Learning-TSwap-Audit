//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test,console2} from "forge-std/Test.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";



contract Handler is Test{

    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("lp");

    int256 startingY;
    int256 startingX;
    int256 expectedDeltaX;
    int256 expectedDeltaY;

    int256 actualDeltaX;
    int256 actualDeltaY;


    constructor(TSwapPool _pool){
        pool = _pool;
        weth = ERC20Mock(_pool.getWeth());
        poolToken = ERC20Mock(_pool.getPoolToken());
    }

    //deposit, swapExactoutput

    function deposit(uint256 wethAmount) public {
        wethAmount = bound(wethAmount, 0, type(uint64).max);
        startingY = int256(weth.balanceOf(address(this)));
        startingX = int256(poolToken.balanceOf(address(this)));
        expectedDeltaY = int256(wethAmount);
        expectedDeltaX = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmount));
    
        //deposit
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider,wethAmount);
        poolToken.mint(address(pool), uint256(expectedDeltaX));
        weth.approve(address(pool), type(uint256).max);
        poolToken.approve(address(pool), type(uint256).max);
        pool.deposit(wethAmount, 0,uint256(expectedDeltaX), uint64(block.timestamp));
        vm.stopPrank();

        //actual
        uint256 endingY = weth.balanceOf(address(this));
        uint256 endingX = poolToken.balanceOf(address(this));

        actualDeltaY = int256(endingY) -int256(startingY);
        actualDeltaX = int256(endingX) - int256(startingX);

        

    }
}