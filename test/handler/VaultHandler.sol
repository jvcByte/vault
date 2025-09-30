// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Vault} from "../../src/Vault.sol";
import "forge-std/Test.sol";
import {ERC20Mock} from "../../src/ERC20.sol";

contract VaultHandler is Test {

    Vault public vault;
    ERC20Mock public erc20;

    address[] public users;
    address public owner;

    mapping(address => uint256) public userBalances;
    mapping(address => uint256) public withdrawn;

    constructor(Vault _vault, ERC20Mock _erc20, address[] memory _users) {
        vault = _vault;
        erc20 = _erc20;
        users = _users;
        owner = vault.owner();

        for(uint256 i = 0; i < _users.length; i++) {
            vm.prank(_users[i]);
            erc20.approve(address(vault), type(uint256).max);
        }
    }

    // Random Deposits
    function deposit(uint256 amount, uint256 userIndex) {
        address user = users[userIndex % users.length];
        amount =  bound(amount, 1e18, 100e18);

        if (erc20.balanceOf(user) >= amount) {
            vm.prank(user);
            vault.deposit(amount, user);

            userBalances[user] += amount;
        }
        
    }

    function withdraw(uint256 amount, uint256 userIndex){
        address user = users[userIndex % users.length];
        uint256 shares = vault.balanceOf(user);
        amount = bound(amount, 1e18, shares);

        if(shares == 0) return;

        vm.startPrank(user);
        try vault.withdraw(amount, user, user) {
            userBalances[user] -= amount;
            withdrawn[user] += amount;
        } catch {
            
        }
        vm.stopPrank();
        
    }

    function redeem(uint256 amount, uint256 userIndex){
        address user = users[userIndex % users.length];
        uint256 shares = vault.balanceOf(user);
        amount = bound(amount, 1e18, shares);

        if(shares == 0) return;

        vm.startPrank(user);
        try vault.redeem(amount, user, user) { 
            uint256 assets = vault.convertToAssets(amount);
            userBalances[user] -= assets;
            withdrawn[user] += assets;
        } catch {
            
        }
        vm.stopPrank();
        
    }
    
}