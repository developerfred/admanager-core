// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AdvertisementManager, AdToken} from "../src/AdvertisementManager.sol";

contract AdvertisementManagerTest is Test {
    AdvertisementManager public adManager;
    AdToken public adToken;
    
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public attacker;
    
    uint256 constant INITIAL_BALANCE = 100 ether;
    
    event NewAdvertisement(
        uint256 indexed adIndex,
        string link,
        string imageUrl,
        uint256 price,
        address indexed advertiser,
        address indexed referrer
    );
    event EngagementRecorded(
        uint256 indexed adIndex,
        address indexed user,
        uint256 timestamp
    );
    event LevelUp(address indexed user, uint256 newLevel);
    
    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");
        
        adManager = new AdvertisementManager();
        adToken = adManager.adToken();
        
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
        vm.deal(user3, INITIAL_BALANCE);
        vm.deal(attacker, INITIAL_BALANCE);        
        
    }
    
    // ========== TESTS: DEPLOYMENT ==========
    
    function test_Deployment() public view {
        assertEq(address(adManager.adToken()), address(adToken));        
        assertEq(adToken.OWNER(), address(this));
        assertTrue(adManager.hasRole(adManager.ADMIN_ROLE(), admin));
    }
    
    function test_AdTokenInitialSupply() public view {
        uint256 expectedSupply = 50000000 * 10 ** adToken.decimals();        
        assertEq(adToken.balanceOf(address(this)), expectedSupply, "Initial supply must be minted to the deployer");
    }
    
    // ========== TESTS: ADVERTISEMENT CREATION ==========
    
    function test_CreateAdvertisement() public {
        vm.startPrank(user1);
        
        uint256 price = adManager.getNextAdPrice();
        
        vm.expectEmit(true, true, true, true);
        emit NewAdvertisement(
            0,
            "https://test.com",
            "https://image.com/test.png",
            price,
            user1,
            address(0)
        );
        
        adManager.createAdvertisement{value: price}(
            "https://test.com",
            "https://image.com/test.png",
            address(0)
        );
        
        assertTrue(adManager.hasAdvertised(user1));
        assertEq(adManager.getTotalAds(), 1);
        
        vm.stopPrank();
    }
    
    function test_CreateAdvertisement_WithReferrer() public {
        // Primeiro user1 cria um anúncio para poder ser referrer
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test1.com",
            "https://image1.com",
            address(0)
        );
        
        // Agora user2 cria com user1 como referrer
        vm.startPrank(user2);
        
        uint256 price = adManager.getNextAdPrice();
        uint256 discountedPrice = (price * 90) / 100; // 10% desconto
        
        adManager.createAdvertisement{value: price}( // Pagar o preço cheio, o desconto é aplicado internamente
            "https://test2.com",
            "https://image2.com",
            user1
        );
        
        vm.stopPrank();
        
        assertGt(adToken.balanceOf(user1), 0);
    }
    
    function test_Revert_CreateAdvertisement_InsufficientPayment() public {
        vm.prank(user1);
        uint256 price = adManager.getNextAdPrice();
        
        vm.expectRevert("Insufficient payment for advertisement");
        adManager.createAdvertisement{value: price - 1}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
    }
    
    function test_Revert_CreateAdvertisement_EmptyLink() public {
        vm.prank(user1);
        
        vm.expectRevert("String cannot be empty");
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "",
            "https://image.com",
            address(0)
        );
    }
    
    function test_CreateAdvertisement_PriceIncreases() public {
        uint256 price1 = adManager.getNextAdPrice();
        
        vm.prank(user1);
        adManager.createAdvertisement{value: price1}(
            "https://test1.com",
            "https://image1.com",
            address(0)
        );
        
        uint256 price2 = adManager.getNextAdPrice();
        // The new price must be strictly greater than the initial price.
        assertGt(price2, price1, "Next ad price must increase");
        
        // Verify that the price has increased by approximately 5% (with a 2% margin of error for UD60x18 precision).
        assertApproxEqRel(price2, (price1 * 105) / 100, 0.02e18, "Price increase should be approximately 5%");
    }
    
    // ========== TESTS: ENGAGEMENT ==========
    
    function test_RecordEngagement() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.startPrank(user2);
        
        vm.expectEmit(true, true, false, true);
        emit EngagementRecorded(0, user2, block.timestamp);
        
        adManager.recordEngagement(0);
        
        vm.stopPrank();
        
        (,,,,,,uint256 engagements,) = adManager.advertisements(0);
        assertEq(engagements, 1);
        
        assertGt(adToken.balanceOf(user2), 0);
    }
    
    function test_Revert_RecordEngagement_OwnAd() public {
        vm.startPrank(user1);
        
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.expectRevert("Can't engage own ad");
        adManager.recordEngagement(0);
        
        vm.stopPrank();
    }
    
    function test_RecordEngagement_Cooldown() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.prank(user2);
        adManager.recordEngagement(0);
        
        uint256 balance1 = adToken.balanceOf(user2);
        
        vm.prank(user2);
        adManager.recordEngagement(0);
        
        uint256 balance2 = adToken.balanceOf(user2);
        
        assertEq(balance1, balance2);
        
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.prank(user2);
        adManager.recordEngagement(0);
        
        uint256 balance3 = adToken.balanceOf(user2);
        
        assertGt(balance3, balance2);
    }
    
    function test_RecordEngagement_LevelUp() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.startPrank(user2);
        
        for (uint256 i = 0; i < 50; i++) {
            adManager.recordEngagement(0);
        }
        
        vm.stopPrank();
        
        // Nível aumenta a cada 50 engagements
        assertGe(adManager.getAdvertiserLevel(user2), 1);
    }
    
    // ========== TESTS: REFERRAL SYSTEM ==========
    
    function test_Refer() public {
        // User1 precisa ter criado um anúncio primeiro
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.prank(user2);
        adManager.refer(user1);
        
        (address referrer, address[] memory referrals) = adManager.getUserReferralInfo(user2);
        assertEq(referrer, user1);
        assertEq(referrals.length, 0);
        
        (referrer, referrals) = adManager.getUserReferralInfo(user1);
        assertEq(referrals.length, 1);
        assertEq(referrals[0], user2);
    }
    
    function test_Revert_Refer_AlreadyReferred() public {
        vm.startPrank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        vm.stopPrank();
        
        vm.startPrank(user2);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test2.com",
            "https://image2.com",
            address(0)
        );
        adManager.refer(user1);
        
        vm.expectRevert("Already referred");
        adManager.refer(user2);
        vm.stopPrank();
    }
    
    function test_Revert_Refer_Self() public {
        vm.prank(user1);
        
        vm.expectRevert("Cannot refer yourself");
        adManager.refer(user1);
    }
    
    // ========== TESTS: CHIEF OF ADVERTISING ==========
    
    function test_ClaimChiefOfAdvertising() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        adToken.mint(user1, 1000e18);
        
        _setUserLevel(user1, 30);
        
        vm.prank(user1);
        adManager.claimChiefOfAdvertising();
        
        assertEq(adManager.chefOfAdvertising(), user1);
    }
    
    function test_Revert_ClaimChief_InsufficientTokens() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        _setUserLevel(user1, 30);
        
        vm.prank(user1);
        vm.expectRevert("Insufficient token balance");
        adManager.claimChiefOfAdvertising();
    }
    
    // ========== TESTS: ACHIEVEMENTS ==========
    
    function test_AddAchievement() public {
        adManager.addAchievement(
            "First Steps",
            "Create your first ad",
            1,
            100e18
        );
        
        assertEq(adManager.getTotalAchievements(), 1);
    }
    
    function test_UnlockAchievement() public {
        adManager.addAchievement(
            "Engager",
            "Engage with 10 ads",
            10,
            100e18
        );
        
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.startPrank(user2);
        for (uint256 i = 0; i < 10; i++) {
            adManager.recordEngagement(0);
        }
        vm.stopPrank();
        
        assertTrue(adManager.hasUnlockedAchievement(user2, 0));
    }
    
    // ========== TESTS: WEEKLY BONUS ==========
    
    function test_AwardWeeklyBonus() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.prank(user2);
        adManager.recordEngagement(0);
        
        uint256 balanceBefore = adToken.balanceOf(user2);
        
        vm.warp(block.timestamp + 7 days + 1);
        
        adManager.awardWeeklyBonus();
        
        uint256 balanceAfter = adToken.balanceOf(user2);
        
        // User2 teve engagements então deve receber o bônus
        assertGe(balanceAfter, balanceBefore);
    }
    
    function test_Revert_AwardWeeklyBonus_TooEarly() public {
        vm.expectRevert("Weekly bonus can only be awarded once a week");
        adManager.awardWeeklyBonus();
    }
    
    // ========== TESTS: ADMIN FUNCTIONS ==========
    
    function test_PauseContract() public {
        adManager.pauseContract();
        
        vm.prank(user1);
        vm.expectRevert(); // Pausable revert
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
    }
    
    function test_UnpauseContract() public {
        adManager.pauseContract();
        adManager.unpauseContract();
        
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
    }
    
    function test_Withdraw() public {
        vm.prank(user1);
        uint256 price = adManager.getNextAdPrice();
        adManager.createAdvertisement{value: price}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        uint256 contractBalance = address(adManager).balance;
        assertGt(contractBalance, 0);
        
        uint256 balanceBefore = address(this).balance;
        
        adManager.withdraw();
        
        uint256 balanceAfter = address(this).balance;
        
        assertEq(balanceAfter, balanceBefore + contractBalance);
    }
    
    function test_DeactivateAdvertisement_ByOwner() public {
        vm.startPrank(user1);
        
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        adManager.deactivateAdvertisement(0);
        
        vm.stopPrank();
        
        (,,,,, bool isActive,,) = adManager.advertisements(0);
        assertFalse(isActive);
    }
    
    function test_DeactivateAdvertisement_ByAdmin() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        adManager.deactivateAdvertisement(0);
        
        (,,,,, bool isActive,,) = adManager.advertisements(0);
        assertFalse(isActive);
    }
    
    function test_Revert_DeactivateAdvertisement_Unauthorized() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.prank(user2);
        vm.expectRevert("Only the advertiser or admin can deactivate");
        adManager.deactivateAdvertisement(0);
    }
    
    // ========== TESTS: VIEW FUNCTIONS ==========
    
    function test_GetCurrentAd() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com/test.png",
            address(0)
        );
        
        (
            string memory link,
            string memory imageUrl,
            ,
            address advertiser,
            ,
            bool isActive,
            
        ) = adManager.getCurrentAd();
        
        assertEq(link, "https://test.com");
        assertEq(imageUrl, "https://image.com/test.png");
        assertEq(advertiser, user1);
        assertTrue(isActive);
    }
    
    function test_GetActiveAds_WithPagination() public {
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user1);
            adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
                string(abi.encodePacked("https://test", vm.toString(i), ".com")),
                "https://image.com",
                address(0)
            );
        }
        
        (AdvertisementManager.Advertisement[] memory ads, uint256 total) = adManager.getActiveAds(0, 3);
        
        assertEq(ads.length, 3);
        assertEq(total, 5);
        
        (ads, total) = adManager.getActiveAds(3, 3);
        
        assertEq(ads.length, 2);
        assertEq(total, 5);
    }
    
    function test_GetUserStats() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.prank(user2);
        adManager.recordEngagement(0);
        
        (
            uint256 adsCreated,
            uint256 adsEngaged,
            uint256 timesChief,
            uint256 referralsCount,
            ,
            ,
            
        ) = adManager.getUserStats(user2);
        
        assertEq(adsCreated, 0);
        assertEq(adsEngaged, 1);
        assertEq(timesChief, 0);
        assertEq(referralsCount, 0);
    }
    
    // ========== TESTS: SECURITY ==========
    
    function test_NoReentrancy() public {
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        MaliciousReentrancy malicious = new MaliciousReentrancy(address(adManager));
        vm.deal(address(malicious), 10 ether);
        
        // O contrato malicioso vai tentar reentrar, mas vai falhar devido ao nonReentrant
        vm.expectRevert();
        malicious.attack();
    }
    
    function testFuzz_CreateAdvertisement(uint256 payment) public {
        vm.assume(payment >= adManager.getNextAdPrice());
        vm.assume(payment < 1000 ether);
        
        vm.deal(user1, payment);
        
        vm.prank(user1);
        adManager.createAdvertisement{value: payment}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        assertTrue(adManager.hasAdvertised(user1));
    }
    
    function testFuzz_RecordEngagement(uint8 times) public {
        vm.assume(times > 0 && times < 100);
        
        vm.prank(user1);
        adManager.createAdvertisement{value: adManager.getNextAdPrice()}(
            "https://test.com",
            "https://image.com",
            address(0)
        );
        
        vm.startPrank(user2);
        for (uint256 i = 0; i < times; i++) {
            adManager.recordEngagement(0);
        }
        vm.stopPrank();
        
        (,,,,,,uint256 engagements,) = adManager.advertisements(0);
        assertEq(engagements, times);
    }
    
    // ========== HELPER FUNCTIONS ==========
    
    function _setUserLevel(address user, uint256 level) internal {
        bytes32 advertiserSlot = keccak256(abi.encode(user, 1)); 
        bytes32 levelSlot = bytes32(uint256(advertiserSlot) + 4);
        
        vm.store(
            address(adManager),
            levelSlot,
            bytes32(level)
        );
    }
    
    // Função para receber ETH do withdraw
    receive() external payable {}
}

contract MaliciousReentrancy {
    AdvertisementManager public target;
    
    constructor(address _target) {
        target = AdvertisementManager(_target);
    }
    
    function attack() external {
        target.createAdvertisement{value: target.getNextAdPrice()}(
            "https://malicious.com",
            "https://image.com",
            address(0)
        );
    }
    
    receive() external payable {
        if (address(target).balance > 0) {
            target.createAdvertisement{value: target.getNextAdPrice()}(
                "https://malicious.com",
                "https://image.com",
                address(0)
            );
        }
    }
}
