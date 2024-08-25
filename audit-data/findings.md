## Highs

### [H-1] `TSwapPool::deposit` is missing deadline check causing transactions  to complete even after the deadline

**Description:**  The `deposit` function accepts the deadline parameter, which according to the documentation is "/// @param deadline The deadline for the transaction to be completed by". However, this parameter is never used. As a consequence, operations that add liquidity to the pool might be executed at unexpected times, in market conditions where deposit rate is unfavorable.

**Impact:** Transactions can be sent when market conditions are unfavorable to deposit, even adding an deadline parameter.

**Proof of Concept:** The `deadline` parameters is unused.

**Recommended Mitigation:** Consider making the following change to the function:

```diff

  function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline  //@audit - high: unused deadline var
    )
        external
+       revertIfDeadlinePassed(uint64 deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint){}
```

### [H-2] Incorrect fee calculation in `TSwapPool::getInputAmountBasedOnOutput` causes protocol to charge high fees, resulting in lost fees

**Description:** The `getInputAmountBasedOnOutput` function is intended to calculate the amount of tokens a user should deposit given an amount of tokens of output tokens. However, the function currently miscalculates the resulting amount, when calculating fee it scales the amount by 10000 instead of 1000.

**Impact:** Protocol takes more fees than intended from users.

**Recommended Mitigation:** 

```diff

    function getInputAmountBasedOnOutput(
        uint256 outputAmount,
        uint256 inputReserves,
        uint256 outputReserves
    )
        public
        pure
        revertIfZero(outputAmount)
        revertIfZero(outputReserves)
-        returns (uint256 inputAmount)
-  {
        
-            ((inputReserves * outputAmount) * 10_000) /
-            ((outputReserves - outputAmount) * 997);
-   }

+      returns (uint256 inputAmount)
+   {
        
+            ((inputReserves * outputAmount) * 1_000) /
+           ((outputReserves - outputAmount) * 997);
+    }


```

### [H-3] Lack of slippage protection in `TSwapPool::swapExactOutput` causes user to potentially receive way fewer tokens

**Description:** The `swapExactOutput` function does not include any sort of slippage protection. This function is similar to what is done in `TSwapPool::swapExactInput`, where the function specifies a `minOutputAmount`, the `swapExactOutput` function should specify a `maxInputAmount`.

**Impact:** If the market conditions change, before the transaction processes, the user could get a much worse swap.

**Proof of Concept:** 
1. The price is WETH right now is 1000 USDC
2. User inputs a `swapExactOutput` looking for 1 WETH
    1. inputToken = USDC
    2. outputToken = WETH
    3. outputAmount = 1
    4. deadline = whatever
3. The function does not offer a maxInput amount 
4. As the transaction is pending in the mempool, the market changes!
And the price moves HUGE -> 1 WETH is now 10,000 USDC. 10x more than the user expected
5. The transaction complete, but the user sent the protocol 10,000 USDC instead of the expected 1,000 USDC

**Recommended Mitigation:** We should include a `maxInputAmount` so the user only has to spend up to a specific amount, and can predict how much they will spend on the protocol.

```diff

function swapExactOutput(
        IERC20 inputToken,
        IERC20 outputToken,
+       uint256 maxInputAmount,
    )
        public
        revertIfZero(outputAmount)
        revertIfDeadlinePassed(deadline)
        returns (uint256 inputAmount)
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        inputAmount = getInputAmountBasedOnOutput(
            outputAmount,
            inputReserves,
            outputReserves
        );

        //slippage! no check if 
        //@audit -> high: need a max input amount

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }

```

### [H-4] `TSwapPool::sellPoolTokens` mismatches input and output tokens causing users to receive the incorrect amount of tokens

**Description:** The `sellPoolTokens` function is intended to allow users to easily sell pool tokens and receive WETH in exchange. Users indicate how many pool tokens they're willing to sell in the `poolTokenAmount` parameter. However, the function currently miscalculaes the swapped amount.

This is due to the fact that the `swapExactOutput` function is called, whereas the `swapExactInput` function is the one that should be called.
Because, Users specify the exact amount of input tokens, not output.

**Impact:** Users will swap the wrong amount of tokens, which is a severe disruption of protocol functionality.

**Recommended Mitigation:** Consider changing the implementation to use `swapExactInput` instead of `swapExactOutput`. Note that this would also require changing the `sellPoolTokens` function to accept a new parameter (ie `minWethToReceive` to be passed to `swapExactInput`)

```diff
    
    function sellPoolTokens(
        uint256 poolTokenAmount
    ) external returns (uint256 wethAmount) {
-      return
-            swapExactOutput(
-               i_poolToken,
-               i_wethToken,
-               poolTokenAmount,
-               uint64(block.timestamp)
            );
    

+          return
+            swapExactOutput(
+               i_poolToken,
+             i_wethToken,
+              poolTokenAmount,
+               uint64(block.timestamp)
            );

    }

```

## Lows

### [L-1] `TSwapPool::LiquidityAdded` event has parameters out of order

**Description:** When the `LiquidityAdded` event is emitted in the `TSwapPool::_addLiquidityMintandTransfer` function, it logs value in an incorrect order, The `poolTokenToDeposit` value should go in the third parameter position,whereas the `wethToDeposit` value should go second.

**Impact:** Event emission is incorrect leaving to off-chain function potentially malfunctioning.

**Recommended Mitigation:** 

```diff

-  emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);

+  emit LiquidityAdded(msg.sender, wethToDeposit, poolTokensToDeposit);

```

### [L-2] Default value return by `TSwapPool::swapExactInput` results in incorrect return value given 

**Description:** The `swapExactInput` function is expected to return the actual amount tokens bought by the caller,However, while is declares the named return value `output` it is never assigned a value, nor uses an explicit return statement.

**Impact:** The return value will always be 0, giving incorrect information to the caller.

**Recommended Mitigation:** 

```diff

    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

-        uint256 outputAmount = getOutputAmountBasedOnInput(
-            inputAmount,
-            inputReserves,
-            outputReserves
-       );

+        uint256 output = getOutputAmountBasedOnInput(
+           inputAmount,
+           inputReserves,
+           outputReserves
+       );


-        if (outputAmount < minOutputAmount) {
-            revert TSwapPool__OutputTooLow(outputAmount, minOutputAmount);
-       }

+        if (output < minOutputAmount) {
+           revert TSwapPool__OutputTooLow(outputAmount, minOutputAmount);
+       }

-        _swap(inputToken, inputAmount, outputToken, outputAmount);
+        _swap(inputToken, inputAmount, outputToken, output);
    }

```

## Informationals

### [I-1] `PoolFactory::PoolFactory__PoolDoesNotExist` is not used and should be removed

```diff
-     error PoolFactory__PoolDoesNotExist(address tokenAddress);  
```

### [I-2] Lacking zero address check

```diff
 constructor(address wethToken) {
+       if(wethToken == address(0))
        {
            revert();
        }
        i_wethToken = wethToken;
    }
```


### [I-3] `PoolFactory::createPool` should use `.symbol()` instead of `.name()` 

```diff

- string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());

+ string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());


```

### [I-4]  Event is missing `indexed` fields

Index event fields make the field more quickly accessible to off-chain tools that parse events. However, note that each index field costs extra gas during emission, so it's not necessarily best to index the maximum allowed per event (three fields). Each event should use three indexed fields if there are three or more fields, and gas usage is not particularly of concern for the events in question. If there are fewer than three fields, all of the fields should be indexed.

<details><summary>4 Found Instances</summary>


- Found in src/PoolFactory.sol [Line: 35](src/PoolFactory.sol#L35)

    ```solidity
        event PoolCreated(address tokenAddress, address poolAddress);
    ```

- Found in src/TSwapPool.sol [Line: 52](src/TSwapPool.sol#L52)

    ```solidity
        event LiquidityAdded(
    ```

- Found in src/TSwapPool.sol [Line: 57](src/TSwapPool.sol#L57)

    ```solidity
        event LiquidityRemoved(
    ```

- Found in src/TSwapPool.sol [Line: 62](src/TSwapPool.sol#L62)

    ```solidity
        event Swap(
    ```

</details>