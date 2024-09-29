// SPDX-License-Identifier: MIT

/**
 * @title AdvertisementManager
 * @dev A decentralized advertisement platform on the Ethereum blockchain
 *
 * ╔═══════════════════════════════════════════════════════════════════════╗
 * ║                                                                       ║
 * ║   █████╗ ██████╗     ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗   ║
 * ║  ██╔══██╗██╔══██╗    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝   ║
 * ║  ███████║██║  ██║    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗  ║
 * ║  ██╔══██║██║  ██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║  ║
 * ║  ██║  ██║██████╔╝    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝  ║
 * ║  ╚═╝  ╚═╝╚═════╝     ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝   ║
 * ║                                                                       ║
 * ╚═══════════════════════════════════════════════════════════════════════╝
 *
 * This project implements a decentralized advertisement platform with the following features:
 *
 * 1. Advertisement Creation and Management:
 *    - Users can create and deactivate advertisements
 *    - Dynamic pricing based on the number of advertisements
 *    - Referral system for discounts and rewards
 *
 * 2. Engagement and Rewards:
 *    - Users earn tokens for engaging with advertisements
 *    - Weekly bonuses for top engagers
 *    - Leveling system based on total engagements
 *
 * 3. Gamification Elements:
 *    - Achievements system with unlockable rewards
 *    - Reputation system affecting advertisement pricing
 *    - Community challenges with shared rewards
 *    - Special events with increased reward multipliers
 *
 * 4. Governance and Roles:
 *    - Admin role for contract management and control
 *    - Chief of Advertising role with additional benefits
 *    - Operator role for day-to-day operations
 *
 * 5. Token Economy:
 *    - Native ERC20 token (AdToken) for platform interactions
 *    - Token minting for rewards and incentives
 *    - Token-based voting power for future governance (to be implemented)
 *
 * 6. Security and Control:
 *    - Pausable contract for emergency situations
 *    - Access control for critical functions
 *    - Reentrancy protection for vulnerable functions
 *
 * 7. Scalability and Performance:
 *    - Efficient data structures for advertisement storage and retrieval
 *    - Batch operations for multiple advertisements
 *
 * This contract aims to create a self-sustaining ecosystem where advertisers,
 * users, and platform contributors are incentivized to participate and grow
 * the network. It leverages blockchain technology to ensure transparency,
 * fairness, and decentralized governance.
 *
 * @author codingsh
 * @notice Use this contract to interact with the decentralized ad platform
 * @dev All function calls are currently implemented without side effects
 */

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import {SD59x18, sd} from "@prb/math/src/SD59x18.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract AdToken is ERC20, AccessControl {
    address public immutable owner;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("AdToken", "A+") {
        owner = owner;
        uint256 initialSupply = 50000000 * 10 ** decimals();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _mint(to, amount);
    }
}

contract AdvertisementManager is ReentrancyGuard, AccessControl, Pausable {
    AdToken public adToken;
    address public chefOfAdvertising;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    UD60x18 public constant INITIAL_PRICE = UD60x18.wrap(300000000000000);
    UD60x18 public constant PRICE_MULTIPLIER = UD60x18.wrap(1.05e18); // 5 em formato UD60x18
    uint256 public constant REFERRAL_DISCOUNT = 1e17; // 10% discount
    uint256 public constant REFERRAL_REWARD = 50e18; // 50 tokens
    uint256 public constant ENGAGEMENT_REWARD = 2e18; // 2 tokens
    uint256 public constant WEEKLY_BONUS = 100e18; // 100 tokens
    uint256 public constant LEVEL_UP_THRESHOLD = 50e18;
    uint256 public constant CHIEF_TOKEN_THRESHOLD = 1000e18; // 1000 tokens
    uint256 public constant CHIEF_REFERRAL_THRESHOLD = 30e18;

    struct Advertisement {
        string link;
        string imageUrl;
        uint256 price;
        address advertiser;
        address referrer;
        bool isActive;
        uint256 engagements;
        uint256 createdAt;
    }

    struct Advertiser {
        bool hasAdvertised;
        uint256 lastAdIndex;
        uint256 totalEngagements;
        uint256 lastEngagementTime;
        uint256 level;
    }

    struct Achievement {
        string name;
        string description;
        uint256 threshold;
        uint256 reward;
    }

    struct CommunityChallenge {
        string description;
        uint256 goal;
        uint256 currentProgress;
        uint256 reward;
        uint256 deadline;
        bool completed;
    }

    struct SpecialEvent {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 rewardMultiplier;
    }

    Advertisement[] public advertisements;
    mapping(address => Advertiser) public advertisers;
    mapping(address => uint256) public weeklyEngagements;
    mapping(address => uint256[]) public userEngagements;
    mapping(address => mapping(uint256 => bool)) public userAchievements;
    mapping(address => uint256) public userReputation;
    mapping(address => address) public referrers;
    mapping(address => address[]) public referrals;
    mapping(address => uint256) private timesAsChief;
    mapping(address => uint256[]) private userCreatedAds;

    Achievement[] public achievements;
    CommunityChallenge public currentChallenge;
    SpecialEvent public currentEvent;

    uint256 public lastWeeklyResetTime;

    event NewAdvertisement(
        string link,
        string imageUrl,
        uint256 price,
        address advertiser,
        address referrer
    );
    event AdvertisementDeactivated(uint256 indexed adIndex);
    event EngagementRewardMinted(address user, uint256 amount);
    event EngagementRecorded(
        uint256 indexed adIndex,
        address user,
        uint256 timestamp
    );
    event WeeklyBonusMinted(address user, uint256 amount);
    event WithdrawCompleted(address owner, uint256 amount);
    event LevelUp(address user, uint256 newLevel);
    event NewChiefOfAdvertising(
        address indexed newChief,
        uint256 tokenBalance,
        uint256 referralLevel
    );
    event AchievementUnlocked(address user, uint256 achievementId, string name);
    event ReputationUpdated(address user, uint256 newReputation);
    event NewReferral(address referred, address referrer);
    event ReferralRewardDistributed(
        address referrer,
        uint256 reward,
        uint256 level
    );
    event NewCommunityChallenge(
        string description,
        uint256 goal,
        uint256 reward,
        uint256 deadline
    );
    event SpecialEventStarted(
        string name,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardMultiplier
    );

    constructor() {
        adToken = new AdToken();
        adToken.grantRole(adToken.MINTER_ROLE(), address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, address(this));
        lastWeeklyResetTime = block.timestamp;
    }

    function getUserCreatedAds(
        address _user
    ) public view returns (Advertisement[] memory) {
        uint256[] memory adIndices = userCreatedAds[_user];
        Advertisement[] memory ads = new Advertisement[](adIndices.length);

        for (uint256 i = 0; i < adIndices.length; i++) {
            ads[i] = advertisements[adIndices[i]];
        }

        return ads;
    }

    function createAdvertisement(
        string memory _link,
        string memory _imageUrl,
        address _referrer
    ) public payable nonReentrant whenNotPaused {
        UD60x18 requiredPrice = UD60x18.wrap(getNextAdPrice());

        bool validReferral = _referrer != address(0) &&
            _referrer != msg.sender &&
            advertisers[_referrer].hasAdvertised;

        if (validReferral) {
            requiredPrice = requiredPrice.mul(
                UD60x18.wrap(1e18).sub(UD60x18.wrap(REFERRAL_DISCOUNT))
            );
        }

        require(
            msg.value >= requiredPrice.unwrap(),
            "Insufficient payment for advertisement"
        );

        uint256 newAdIndex = advertisements.length;
        userCreatedAds[msg.sender].push(newAdIndex);
        advertisements.push(
            Advertisement(
                _link,
                _imageUrl,
                requiredPrice.unwrap(),
                msg.sender,
                validReferral ? _referrer : address(0),
                true,
                0,
                block.timestamp
            )
        );
        advertisers[msg.sender].hasAdvertised = true;
        advertisers[msg.sender].lastAdIndex = newAdIndex;

        emit NewAdvertisement(
            _link,
            _imageUrl,
            requiredPrice.unwrap(),
            msg.sender,
            validReferral ? _referrer : address(0)
        );

        if (validReferral) {
            UD60x18 referralBonus = UD60x18.wrap(REFERRAL_REWARD).add(
                UD60x18
                    .wrap(REFERRAL_REWARD)
                    .mul(UD60x18.wrap(advertisers[_referrer].level))
                    .div(UD60x18.wrap(10e18))
            );
            adToken.mint(_referrer, referralBonus.unwrap());
            distributeReferralRewards(_referrer, referralBonus.unwrap());
        }

        if (
            chefOfAdvertising != address(0) && chefOfAdvertising != msg.sender
        ) {
            UD60x18 chiefBonus = requiredPrice.mul(UD60x18.wrap(5e16)); // 5%
            adToken.mint(chefOfAdvertising, chiefBonus.unwrap());
        }

        if (msg.value > requiredPrice.unwrap()) {
            payable(msg.sender).transfer(msg.value - requiredPrice.unwrap());
        }

        updateReputation(msg.sender, 10);
        checkAndAwardAchievements(msg.sender);
        updateChallengeProgress(1);
    }

    function recordEngagement(
        uint256 _adIndex
    ) external nonReentrant whenNotPaused {
        require(_adIndex < advertisements.length, "Invalid ad index");
        Advertisement storage ad = advertisements[_adIndex];
        require(ad.isActive, "Ad not active");
        require(msg.sender != ad.advertiser, "Can't engage own ad");

        // Atualizações locais para economizar gas
        Advertiser storage user = advertisers[msg.sender];
        ad.engagements++;
        user.totalEngagements++;
        weeklyEngagements[msg.sender]++;
        userEngagements[msg.sender].push(_adIndex);

        // Checagem e atualização de nível
        uint256 newLevel = user.totalEngagements / LEVEL_UP_THRESHOLD;
        if (newLevel > user.level) {
            user.level = newLevel;
            emit LevelUp(msg.sender, newLevel);
        }

        // Recompensa de engajamento
        uint256 lastEngagement = user.lastEngagementTime;
        if (block.timestamp > lastEngagement + 1 days || lastEngagement == 0) {
            uint256 baseReward = (ENGAGEMENT_REWARD * (100 + user.level)) / 100; // Simplificado
            uint256 eventMultiplier = getEventRewardMultiplier();
            uint256 reward = (baseReward * eventMultiplier) / 100;

            adToken.mint(msg.sender, reward);
            user.lastEngagementTime = block.timestamp;
            emit EngagementRewardMinted(msg.sender, reward);

            if (
                chefOfAdvertising != address(0) &&
                chefOfAdvertising != msg.sender
            ) {
                uint256 chiefBonus = (reward * 5) / 100; // 5% bonus
                adToken.mint(chefOfAdvertising, chiefBonus);
            }
        }

        emit EngagementRecorded(_adIndex, msg.sender, block.timestamp);
        updateReputation(msg.sender, 1);
        checkAndAwardAchievements(msg.sender);
        updateChallengeProgress(1);
    }

    function awardWeeklyBonus() public nonReentrant whenNotPaused {
        require(
            block.timestamp >= lastWeeklyResetTime + 7 days,
            "Weekly bonus can only be awarded once a week"
        );

        address topEngager = address(0);
        uint256 maxEngagements = 0;

        for (uint256 i = 0; i < advertisements.length; i++) {
            address advertiser = advertisements[i].advertiser;
            if (weeklyEngagements[advertiser] > maxEngagements) {
                maxEngagements = weeklyEngagements[advertiser];
                topEngager = advertiser;
            }
        }

        if (topEngager != address(0)) {
            UD60x18 bonus = UD60x18.wrap(WEEKLY_BONUS).add(
                UD60x18
                    .wrap(WEEKLY_BONUS)
                    .mul(UD60x18.wrap(advertisers[topEngager].level))
                    .div(UD60x18.wrap(10e18))
            );
            adToken.mint(topEngager, bonus.unwrap());
            emit WeeklyBonusMinted(topEngager, bonus.unwrap());
        }

        // Reset weekly engagements
        for (uint256 i = 0; i < advertisements.length; i++) {
            address advertiser = advertisements[i].advertiser;
            weeklyEngagements[advertiser] = 0;
        }

        lastWeeklyResetTime = block.timestamp;
    }

    function deactivateAdvertisement(uint256 _adIndex) public {
        require(
            _adIndex < advertisements.length,
            "Invalid advertisement index"
        );
        require(
            msg.sender == advertisements[_adIndex].advertiser ||
                hasRole(ADMIN_ROLE, msg.sender),
            "Only the advertiser or admin can deactivate"
        );
        advertisements[_adIndex].isActive = false;
        emit AdvertisementDeactivated(_adIndex);
    }

    function getCurrentAd()
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            address,
            address,
            bool,
            uint256
        )
    {
        require(advertisements.length > 0, "No advertisements yet");
        for (int i = int(advertisements.length) - 1; i >= 0; i--) {
            if (advertisements[uint(i)].isActive) {
                Advertisement memory ad = advertisements[uint(i)];
                return (
                    ad.link,
                    ad.imageUrl,
                    ad.price,
                    ad.advertiser,
                    ad.referrer,
                    ad.isActive,
                    ad.engagements
                );
            }
        }
        revert("No active advertisements");
    }

    function getNextAdPrice() public view returns (uint256) {
        if (advertisements.length == 0) {
            return INITIAL_PRICE.unwrap();
        }
        UD60x18 price = INITIAL_PRICE.mul(
            PRICE_MULTIPLIER.pow(ud(advertisements.length))
        );
        return price.unwrap();
    }

    function getAdTokenBalance(address _address) public view returns (uint256) {
        return adToken.balanceOf(_address);
    }

    function hasAdvertised(address _address) public view returns (bool) {
        return advertisers[_address].hasAdvertised;
    }

    function withdraw() public onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(msg.sender).transfer(balance);

        emit WithdrawCompleted(msg.sender, balance);
    }

    function getAdvertiserLevel(
        address _advertiser
    ) public view returns (uint256) {
        return advertisers[_advertiser].level;
    }

    function getAdvertiserTotalEngagements(
        address _advertiser
    ) public view returns (uint256) {
        return advertisers[_advertiser].totalEngagements;
    }

    function getUserEngagements(
        address _user
    ) public view returns (uint256[] memory) {
        return userEngagements[_user];
    }

    function getMultipleAds(
        uint256[] memory _indices
    ) public view returns (Advertisement[] memory) {
        Advertisement[] memory result = new Advertisement[](_indices.length);
        for (uint256 i = 0; i < _indices.length; i++) {
            require(
                _indices[i] < advertisements.length,
                "Invalid advertisement index"
            );
            result[i] = advertisements[_indices[i]];
        }
        return result;
    }

    function getTotalAds() public view returns (uint256) {
        return advertisements.length;
    }

    function getActiveAds() public view returns (Advertisement[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < advertisements.length; i++) {
            if (advertisements[i].isActive) {
                activeCount++;
            }
        }

        Advertisement[] memory activeAds = new Advertisement[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < advertisements.length; i++) {
            if (advertisements[i].isActive) {
                activeAds[index] = advertisements[i];
                index++;
            }
        }

        return activeAds;
    }

    function withdrawTokens() public onlyRole(ADMIN_ROLE) {
        uint256 contractBalance = adToken.balanceOf(address(this));
        require(
            adToken.transfer(msg.sender, contractBalance),
            "Transfer failed"
        );
    }

    function getTimesAsChief(address _user) public view returns (uint256) {
        return timesAsChief[_user];
    }

    function claimChiefOfAdvertising() public nonReentrant {
        require(
            hasAdvertised(msg.sender),
            "Must have created an advertisement"
        );
        require(
            adToken.balanceOf(msg.sender) >= CHIEF_TOKEN_THRESHOLD,
            "Insufficient token balance"
        );
        require(
            getAdvertiserLevel(msg.sender) >= CHIEF_REFERRAL_THRESHOLD,
            "Insufficient referral level"
        );

        chefOfAdvertising = msg.sender;
        timesAsChief[msg.sender]++;

        emit NewChiefOfAdvertising(
            msg.sender,
            adToken.balanceOf(msg.sender),
            getAdvertiserLevel(msg.sender)
        );
    }

    function getCurrentChief() public view returns (address, uint256, uint256) {
        return (
            chefOfAdvertising,
            adToken.balanceOf(chefOfAdvertising),
            getAdvertiserLevel(chefOfAdvertising)
        );
    }

    function addAchievement(
        string memory _name,
        string memory _description,
        uint256 _threshold,
        uint256 _reward
    ) public onlyRole(ADMIN_ROLE) {
        achievements.push(
            Achievement(_name, _description, _threshold, _reward)
        );
    }

    function checkAndAwardAchievements(address user) internal {
        for (uint256 i = 0; i < achievements.length; i++) {
            if (
                !userAchievements[user][i] &&
                advertisers[user].totalEngagements >= achievements[i].threshold
            ) {
                userAchievements[user][i] = true;
                adToken.mint(user, achievements[i].reward);
                emit AchievementUnlocked(user, i, achievements[i].name);
            }
        }
    }

    function updateReputation(address user, uint256 amount) internal {
        userReputation[user] += amount;
        emit ReputationUpdated(user, userReputation[user]);
    }

    function getReputationDiscount(address user) public view returns (uint256) {
        return ud(userReputation[user]).mul(ud(0.05e18)).unwrap(); // 5%
    }

    function refer(address _referrer) public {
        require(referrers[msg.sender] == address(0), "Already referred");
        require(_referrer != msg.sender, "Cannot refer yourself");
        referrers[msg.sender] = _referrer;
        referrals[_referrer].push(msg.sender);
        emit NewReferral(msg.sender, _referrer);
    }

    function distributeReferralRewards(
        address _user,
        uint256 _amount
    ) internal {
        address currentReferrer = referrers[_user];
        UD60x18 amount = ud(_amount);
        for (uint256 i = 0; i < 3 && currentReferrer != address(0); i++) {
            UD60x18 reward = amount.mul(ud(10e18).sub(ud(i * 2e18))).div(
                ud(100e18)
            ); // 10%, 8%, 6%
            adToken.mint(currentReferrer, reward.unwrap());
            emit ReferralRewardDistributed(currentReferrer, reward.unwrap(), i);
            currentReferrer = referrers[currentReferrer];
        }
    }

    function startNewCommunityChallenge(
        string memory _description,
        uint256 _goal,
        uint256 _reward,
        uint256 _duration
    ) public onlyRole(ADMIN_ROLE) {
        require(
            currentChallenge.completed ||
                currentChallenge.deadline < block.timestamp,
            "Current challenge still active"
        );
        currentChallenge = CommunityChallenge(
            _description,
            _goal,
            0,
            _reward,
            block.timestamp + _duration,
            false
        );
        emit NewCommunityChallenge(
            _description,
            _goal,
            _reward,
            block.timestamp + _duration
        );
    }

    function updateChallengeProgress(uint256 _progress) internal {
        if (
            !currentChallenge.completed &&
            block.timestamp <= currentChallenge.deadline
        ) {
            currentChallenge.currentProgress += _progress;
            if (currentChallenge.currentProgress >= currentChallenge.goal) {
                currentChallenge.completed = true;
                distributeCommunityReward();
            }
        }
    }

    function distributeCommunityReward() internal {
        require(currentChallenge.completed, "Challenge not completed");
        uint256 rewardPerParticipant = currentChallenge.reward /
            advertisements.length;
        for (uint256 i = 0; i < advertisements.length; i++) {
            adToken.mint(advertisements[i].advertiser, rewardPerParticipant);
        }
    }

    function startSpecialEvent(
        string memory _name,
        uint256 _duration,
        uint256 _rewardMultiplier
    ) public onlyRole(ADMIN_ROLE) {
        currentEvent = SpecialEvent(
            _name,
            block.timestamp,
            block.timestamp + _duration,
            _rewardMultiplier
        );
        emit SpecialEventStarted(
            _name,
            block.timestamp,
            block.timestamp + _duration,
            _rewardMultiplier
        );
    }

    function isSpecialEventActive() public view returns (bool) {
        return
            block.timestamp >= currentEvent.startTime &&
            block.timestamp <= currentEvent.endTime;
    }

    function getEventRewardMultiplier() public view returns (uint256) {
        return isSpecialEventActive() ? currentEvent.rewardMultiplier : 100;
    }

    function pauseContract() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpauseContract() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function recoverERC20(
        address _tokenAddress,
        uint256 _amount
    ) public onlyRole(ADMIN_ROLE) {
        require(
            _tokenAddress != address(adToken),
            "Cannot recover the main token"
        );
        IERC20(_tokenAddress).transfer(msg.sender, _amount);
    }

    function getAdvertiserInfo(
        address _advertiser
    ) public view returns (bool, uint256, uint256, uint256, uint256, uint256) {
        Advertiser memory advertiser = advertisers[_advertiser];
        return (
            advertiser.hasAdvertised,
            advertiser.lastAdIndex,
            advertiser.totalEngagements,
            advertiser.lastEngagementTime,
            advertiser.level,
            userReputation[_advertiser]
        );
    }

    function getTotalAchievements() public view returns (uint256) {
        return achievements.length;
    }

    function hasUnlockedAchievement(
        address _user,
        uint256 _achievementId
    ) public view returns (bool) {
        require(_achievementId < achievements.length, "Invalid achievement ID");
        return userAchievements[_user][_achievementId];
    }

    function getCurrentChallengeInfo()
        public
        view
        returns (string memory, uint256, uint256, uint256, uint256, bool)
    {
        return (
            currentChallenge.description,
            currentChallenge.goal,
            currentChallenge.currentProgress,
            currentChallenge.reward,
            currentChallenge.deadline,
            currentChallenge.completed
        );
    }

    function getCurrentEventInfo()
        public
        view
        returns (string memory, uint256, uint256, uint256)
    {
        return (
            currentEvent.name,
            currentEvent.startTime,
            currentEvent.endTime,
            currentEvent.rewardMultiplier
        );
    }

    function getUserEngagedAds(
        address _user
    ) public view returns (Advertisement[] memory) {
        uint256[] memory engagedIndices = userEngagements[_user];
        Advertisement[] memory engagedAds = new Advertisement[](
            engagedIndices.length
        );

        for (uint256 i = 0; i < engagedIndices.length; i++) {
            engagedAds[i] = advertisements[engagedIndices[i]];
        }

        return engagedAds;
    }

    function getUserReferralInfo(
        address _user
    ) public view returns (address, address[] memory) {
        return (referrers[_user], referrals[_user]);
    }

    function getUserAchievementProgress(
        address _user
    ) public view returns (bool[] memory) {
        bool[] memory unlockedAchievements = new bool[](achievements.length);

        for (uint256 i = 0; i < achievements.length; i++) {
            unlockedAchievements[i] = userAchievements[_user][i];
        }

        return unlockedAchievements;
    }

    function getUserChallengeParticipation(
        address _user
    ) public view returns (bool) {
        for (uint256 i = 0; i < advertisements.length; i++) {
            if (advertisements[i].advertiser == _user) {
                return true;
            }
        }
        return false;
    }

    function getUserEventParticipation(
        address _user
    ) public view returns (bool) {
        if (isSpecialEventActive()) {
            for (uint256 i = 0; i < advertisements.length; i++) {
                if (
                    advertisements[i].advertiser == _user &&
                    advertisements[i].createdAt >= currentEvent.startTime &&
                    advertisements[i].createdAt <= currentEvent.endTime
                ) {
                    return true;
                }
            }
        }
        return false;
    }

    function getUserStats(
        address _user
    )
        public
        view
        returns (
            uint256 adsCreated,
            uint256 adsEngaged,
            uint256 timesChief,
            uint256 referralsCount,
            uint256 achievementsUnlocked,
            bool challengeParticipation,
            bool eventParticipation
        )
    {
        adsCreated = userCreatedAds[_user].length;
        adsEngaged = userEngagements[_user].length;
        timesChief = timesAsChief[_user];
        referralsCount = referrals[_user].length;

        uint256 achievementCount = 0;
        for (uint256 i = 0; i < achievements.length; i++) {
            if (userAchievements[_user][i]) {
                achievementCount++;
            }
        }
        achievementsUnlocked = achievementCount;

        challengeParticipation = getUserChallengeParticipation(_user);
        eventParticipation = getUserEventParticipation(_user);
    }
}
