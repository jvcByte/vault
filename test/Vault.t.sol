// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ERC20Mock} from "../src/ERC20.sol";

contract VaultTest is Test {

    // ==================== State Variables ====================
    Vault public vault;
    ERC20Mock public erc20;

    address public owner = makeAddr("owner");
    address public jvc = makeAddr("jvc");
    address public ife = makeAddr("ife");
    address public susan = makeAddr("susan");

    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant INITIAL_FEE = 100;

    // ===================== Events =====================
    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event EmergencyWithdraw(address indexed user, uint256 assets);

    // ==================== Functions ====================
    function setUp() public {

        // Deploy token and vault
        erc20 = new ERC20Mock("VaultToken", "VT");

        // Deploy vault
        vault = new Vault(address(erc20), INITIAL_FEE, owner);

        // Mint initials balance
        erc20.mint(jvc, INITIAL_BALANCE);
        erc20.mint(ife, INITIAL_BALANCE);
        erc20.mint(susan, INITIAL_BALANCE);

        // Set Approval 
        vm.prank(jvc);
        erc20.approve(address(vault), type(uint256).max);

        vm.prank(ife);
        erc20.approve(address(vault), type(uint256).max);

        vm.prank(susan);
        erc20.approve(address(vault), type(uint256).max);
        console.log("JVC balance: ", erc20.balanceOf(jvc));
        console.log("JVC: ", jvc);
        console.log("IFE balance: ", erc20.balanceOf(ife));
        console.log("IFE: ", ife);
        console.log("SUSAN balance: ", erc20.balanceOf(susan));
        console.log("SUSAN: ", susan);
        console.log("Vault balance: ", erc20.balanceOf(address(vault)));
        console.log("Vault: ", address(vault));
        console.log("ERC20: ", address(erc20));
    
    }

    function test_Constructor() public view {
        assertEq(vault.owner(), owner);
        assertEq(address(vault.asset()), address(erc20));
        assertEq(vault.feeRate(), INITIAL_FEE);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function test_ConvertToShares() public {
        // 1:1 ratio
        assertEq(vault.convertToShares(INITIAL_BALANCE), INITIAL_BALANCE);
        assertEq(vault.convertToShares(100e18), 100e18);
        assertEq(vault.convertToShares(type(uint256).max), type(uint256).max);
        
    }

    function test_PreviewDeposit() public {
        uint256 assets = 100e18;
        uint256 shares = vault.previewDeposit(assets);
        assertEq(shares, assets);
    }

    // ==================== Test Deposit ====================
    function test_Deposit() public {
        uint256 depositAmount = 100e18;
        

        vm.expectEmit(true, true, false, true);
        emit Deposit(jvc, depositAmount, depositAmount);
        
        vm.prank(jvc);
        uint256 shares = vault.deposit(depositAmount, jvc);

        assertEq(shares, depositAmount);
        assertEq(vault.balanceOf(jvc), depositAmount);
        assertEq(vault.totalSupply(), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(erc20.balanceOf(jvc), INITIAL_BALANCE - depositAmount);
        assertEq(erc20.balanceOf(address(vault)), depositAmount);
        
    }

    function testFUzz_DEposit(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1000, INITIAL_BALANCE);

        vm.prank(ife);
        uint256 shares = vault.deposit(depositAmount, ife);

        assertEq(shares, depositAmount);
        assertEq(vault.balanceOf(ife), depositAmount);
        assertEq(vault.totalSupply(), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(erc20.balanceOf(ife), INITIAL_BALANCE - depositAmount);
        assertEq(erc20.balanceOf(address(vault)), depositAmount);
        
    }

    function test_Pause() public {
        uint256 depositAmount = 100e18;
        vm.prank(owner);
        vault.pause();
        assertEq(vault.paused(), true);

        vm.prank(susan);
        vm.expectRevert();
        vault.deposit(depositAmount, susan);

    }


}
