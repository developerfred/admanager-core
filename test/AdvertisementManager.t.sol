// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AdvertisementManager.sol";

contract AdvertisementManagerTest is Test {
    AdvertisementManager public adManager;
    address public owner;
    address public user;

    receive() external payable {}

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        vm.prank(owner);
        adManager = new AdvertisementManager();
        vm.deal(user, 1 ether);
    }

    function testInitialPrice() public {
        assertEq(adManager.getNextAdPrice(), 300000000000000);
    }

    function testCreateAdvertisement() public {
        vm.prank(user);
        adManager.createAdvertisement{value: 300000000000000}("https://example.com", "https://example.com/image.jpg");

        (string memory link, string memory imageUrl, uint256 price) = adManager.getCurrentAd();
        assertEq(link, "https://example.com");
        assertEq(imageUrl, "https://example.com/image.jpg");
        assertEq(price, 300000000000000);
    }

    function testPriceIncrease() public {
        vm.prank(user);
        adManager.createAdvertisement{value: 300000000000000}("https://example1.com", "https://example1.com/image.jpg");

        uint256 secondPrice = adManager.getNextAdPrice();
        assertEq(secondPrice, 1500000000000000);

        vm.prank(user);
        adManager.createAdvertisement{value: secondPrice}("https://example2.com", "https://example2.com/image.jpg");

        (string memory link, , uint256 price) = adManager.getCurrentAd();
        assertEq(link, "https://example2.com");
        assertEq(price, secondPrice);
    }

    function testInsufficientPayment() public {
        vm.prank(user);
        vm.expectRevert("Insufficient payment for advertisement");
        adManager.createAdvertisement{value: 200000000000000}("https://example.com", "https://example.com/image.jpg");
    }

    function testWithdraw() public {
        vm.prank(user);
        adManager.createAdvertisement{value: 300000000000000}("https://example.com", "https://example.com/image.jpg");

        uint256 initialBalance = address(owner).balance;
        vm.prank(owner);
        adManager.withdraw();
        assertEq(address(owner).balance - initialBalance, 300000000000000);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.prank(user);
        vm.expectRevert("Only the owner can call this function");
        adManager.withdraw();
    }
}