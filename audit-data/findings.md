## Medium

### [M-1] `TSwapPool::deposit` is missing deadline check causing transactions  to complete even after the deadline

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