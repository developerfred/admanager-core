// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

/**
 * @title AdToken
 * @dev ERC20 token for the advertisement platform
 */
contract AdToken is ERC20, AccessControl {
    address public immutable OWNER;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("AdToken", "A+") {
        OWNER = msg.sender;
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

/**
 * @title AdvertisementManager
 * @dev Gerencia anúncios e recompensas na plataforma
 */
contract AdvertisementManager is ReentrancyGuard, AccessControl, Pausable {
    AdToken public adToken;
    address public chefOfAdvertising;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Constantes
    UD60x18 public constant INITIAL_PRICE = UD60x18.wrap(300000000000000);
    UD60x18 public constant PRICE_MULTIPLIER = UD60x18.wrap(1.05e18);
    uint256 public constant REFERRAL_DISCOUNT = 1e17; // 10%
    uint256 public constant REFERRAL_REWARD = 50e18;
    uint256 public constant ENGAGEMENT_REWARD = 2e18;
    uint256 public constant WEEKLY_BONUS = 100e18;
    uint256 public constant LEVEL_UP_THRESHOLD = 50e18;
    uint256 public constant CHIEF_TOKEN_THRESHOLD = 1000e18;
    uint256 public constant CHIEF_REFERRAL_THRESHOLD = 30e18;
    uint256 public constant MAX_REFERRAL_LEVELS = 3;
    uint256 public constant MAX_STRING_LENGTH = 500;

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

    uint256 public currentWeekEpoch;
    mapping(uint256 => mapping(address => uint256)) public weeklyEngagementsByEpoch;

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
        uint256 indexed adIndex,
        string link,
        string imageUrl,
        uint256 price,
        address indexed advertiser,
        address indexed referrer
    );
    event AdvertisementDeactivated(uint256 indexed adIndex);
    event EngagementRewardMinted(address indexed user, uint256 amount);
    event EngagementRecorded(uint256 indexed adIndex, address indexed user, uint256 timestamp);
    event WeeklyBonusMinted(address indexed user, uint256 amount);
    event WithdrawCompleted(address indexed owner, uint256 amount);
    event LevelUp(address indexed user, uint256 newLevel);
    event NewChiefOfAdvertising(address indexed newChief, uint256 tokenBalance, uint256 referralLevel);
    event AchievementUnlocked(address indexed user, uint256 achievementId, string name);
    event ReputationUpdated(address indexed user, uint256 newReputation);
    event NewReferral(address indexed referred, address indexed referrer);
    event ReferralRewardDistributed(address indexed referrer, uint256 reward, uint256 level);
    event NewCommunityChallenge(string description, uint256 goal, uint256 reward, uint256 deadline);
    event SpecialEventStarted(string name, uint256 startTime, uint256 endTime, uint256 rewardMultiplier);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount);

    constructor() {
        adToken = new AdToken();
        adToken.grantRole(adToken.MINTER_ROLE(), address(this));
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, address(this));
        lastWeeklyResetTime = block.timestamp;
        currentWeekEpoch = 0;
    }

    // ========== MODIFIERS ==========

    modifier validString(string memory str) {
        require(bytes(str).length > 0, "String cannot be empty");
        require(bytes(str).length <= MAX_STRING_LENGTH, "String too long");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    // ========== ADVERTISEMENT FUNCTIONS ==========

    function createAdvertisement(string memory _link, string memory _imageUrl, address _referrer)
        public
        payable
        nonReentrant
        whenNotPaused
        validString(_link)
        validString(_imageUrl)
    {
        UD60x18 requiredPrice = UD60x18.wrap(getNextAdPrice());

        bool validReferral = _referrer != address(0) && _referrer != msg.sender && advertisers[_referrer].hasAdvertised;

        if (validReferral) {
            requiredPrice = requiredPrice.mul(UD60x18.wrap(1e18).sub(UD60x18.wrap(REFERRAL_DISCOUNT)));
        }

        require(msg.value >= requiredPrice.unwrap(), "Insufficient payment for advertisement");

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
            newAdIndex, _link, _imageUrl, requiredPrice.unwrap(), msg.sender, validReferral ? _referrer : address(0)
        );

        if (validReferral) {
            _distributeReferralReward(_referrer);
        }

        address cachedChief = chefOfAdvertising;
        if (cachedChief != address(0) && cachedChief != msg.sender) {
            UD60x18 chiefBonus = requiredPrice.mul(UD60x18.wrap(5e16));
            adToken.mint(cachedChief, chiefBonus.unwrap());
        }

        if (msg.value > requiredPrice.unwrap()) {
            payable(msg.sender).transfer(msg.value - requiredPrice.unwrap());
        }

        updateReputation(msg.sender, 10);
        checkAndAwardAchievements(msg.sender);
        updateChallengeProgress(1);
    }

    function recordEngagement(uint256 _adIndex) external nonReentrant whenNotPaused {
        require(_adIndex < advertisements.length, "Invalid ad index");
        Advertisement storage ad = advertisements[_adIndex];
        require(ad.isActive, "Ad not active");
        require(msg.sender != ad.advertiser, "Can't engage own ad");

        Advertiser storage user = advertisers[msg.sender];
        ad.engagements++;
        user.totalEngagements++;
        weeklyEngagementsByEpoch[currentWeekEpoch][msg.sender]++;
        userEngagements[msg.sender].push(_adIndex);

        uint256 newLevel = user.totalEngagements / LEVEL_UP_THRESHOLD;
        if (newLevel > user.level) {
            user.level = newLevel;
            emit LevelUp(msg.sender, newLevel);
        }

        uint256 lastEngagement = user.lastEngagementTime;
        if (block.timestamp > lastEngagement + 1 days || lastEngagement == 0) {
            uint256 baseReward = (ENGAGEMENT_REWARD * (100 + user.level)) / 100;
            uint256 eventMultiplier = getEventRewardMultiplier();
            uint256 reward = (baseReward * eventMultiplier) / 100;

            user.lastEngagementTime = block.timestamp;

            adToken.mint(msg.sender, reward);
            emit EngagementRewardMinted(msg.sender, reward);

            address cachedChief = chefOfAdvertising;
            if (cachedChief != address(0) && cachedChief != msg.sender) {
                uint256 chiefBonus = (reward * 5) / 100;
                adToken.mint(cachedChief, chiefBonus);
            }
        }

        emit EngagementRecorded(_adIndex, msg.sender, block.timestamp);
        updateReputation(msg.sender, 1);
        checkAndAwardAchievements(msg.sender);
        updateChallengeProgress(1);
    }

    function awardWeeklyBonus() public nonReentrant whenNotPaused {
        require(block.timestamp >= lastWeeklyResetTime + 7 days, "Weekly bonus can only be awarded once a week");

        address topEngager = address(0);
        uint256 maxEngagements = 0;

        uint256 adsToCheck = advertisements.length > 100 ? 100 : advertisements.length;

        for (uint256 i = 0; i < adsToCheck; i++) {
            address advertiser = advertisements[i].advertiser;
            uint256 engagements = weeklyEngagementsByEpoch[currentWeekEpoch][advertiser];

            if (engagements > maxEngagements) {
                maxEngagements = engagements;
                topEngager = advertiser;
            }
        }

        if (topEngager != address(0) && maxEngagements > 0) {
            UD60x18 bonus = UD60x18.wrap(WEEKLY_BONUS).add(
                UD60x18.wrap(WEEKLY_BONUS).mul(UD60x18.wrap(advertisers[topEngager].level)).div(UD60x18.wrap(10e18))
            );
            adToken.mint(topEngager, bonus.unwrap());
            emit WeeklyBonusMinted(topEngager, bonus.unwrap());
        }

        currentWeekEpoch++;
        lastWeeklyResetTime = block.timestamp;
    }

    function deactivateAdvertisement(uint256 _adIndex) public {
        require(_adIndex < advertisements.length, "Invalid advertisement index");
        require(
            msg.sender == advertisements[_adIndex].advertiser || hasRole(ADMIN_ROLE, msg.sender),
            "Only the advertiser or admin can deactivate"
        );
        advertisements[_adIndex].isActive = false;
        emit AdvertisementDeactivated(_adIndex);
    }

    // ========== REFERRAL SYSTEM ==========

    function refer(address _referrer) public validAddress(_referrer) {
        require(referrers[msg.sender] == address(0), "Already referred");
        require(_referrer != msg.sender, "Cannot refer yourself");
        require(advertisers[_referrer].hasAdvertised, "Referrer must have advertised");

        referrers[msg.sender] = _referrer;
        referrals[_referrer].push(msg.sender);
        emit NewReferral(msg.sender, _referrer);
    }

    function _distributeReferralReward(address _user) internal {
        UD60x18 referralBonus = UD60x18.wrap(REFERRAL_REWARD).add(
            UD60x18.wrap(REFERRAL_REWARD).mul(UD60x18.wrap(advertisers[_user].level)).div(UD60x18.wrap(10e18))
        );

        adToken.mint(_user, referralBonus.unwrap());
        distributeReferralRewards(_user, referralBonus.unwrap());
    }

    function distributeReferralRewards(address _user, uint256 _amount) internal {
        address currentReferrer = referrers[_user];
        UD60x18 amount = ud(_amount);

        for (uint256 i = 0; i < MAX_REFERRAL_LEVELS && currentReferrer != address(0); i++) {
            uint256 percentage = 10 - (i * 2);
            if (percentage < 2) break;

            UD60x18 reward = amount.mul(ud(percentage * 1e18)).div(ud(100e18));
            adToken.mint(currentReferrer, reward.unwrap());
            emit ReferralRewardDistributed(currentReferrer, reward.unwrap(), i);
            currentReferrer = referrers[currentReferrer];
        }
    }

    // ========== CHIEF OF ADVERTISING ==========

    function claimChiefOfAdvertising() public nonReentrant {
        require(hasAdvertised(msg.sender), "Must have created an advertisement");
        require(adToken.balanceOf(msg.sender) >= CHIEF_TOKEN_THRESHOLD, "Insufficient token balance");
        require(getAdvertiserLevel(msg.sender) >= CHIEF_REFERRAL_THRESHOLD, "Insufficient referral level");

        chefOfAdvertising = msg.sender;
        timesAsChief[msg.sender]++;

        emit NewChiefOfAdvertising(msg.sender, adToken.balanceOf(msg.sender), getAdvertiserLevel(msg.sender));
    }

    // ========== ACHIEVEMENTS & REPUTATION ==========

    function addAchievement(string memory _name, string memory _description, uint256 _threshold, uint256 _reward)
        public
        onlyRole(ADMIN_ROLE)
        validString(_name)
        validString(_description)
    {
        require(_threshold > 0, "Threshold must be positive");
        achievements.push(Achievement(_name, _description, _threshold, _reward));
    }

    function checkAndAwardAchievements(address user) internal {
        for (uint256 i = 0; i < achievements.length; i++) {
            if (!userAchievements[user][i] && advertisers[user].totalEngagements >= achievements[i].threshold) {
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
        return ud(userReputation[user]).mul(ud(0.05e18)).unwrap();
    }

    // ========== COMMUNITY CHALLENGES ==========

    function startNewCommunityChallenge(string memory _description, uint256 _goal, uint256 _reward, uint256 _duration)
        public
        onlyRole(ADMIN_ROLE)
        validString(_description)
    {
        require(_goal > 0, "Goal must be positive");
        require(_duration > 0, "Duration must be positive");
        require(
            currentChallenge.completed || currentChallenge.deadline < block.timestamp, "Current challenge still active"
        );

        currentChallenge = CommunityChallenge(_description, _goal, 0, _reward, block.timestamp + _duration, false);

        emit NewCommunityChallenge(_description, _goal, _reward, block.timestamp + _duration);
    }

    function updateChallengeProgress(uint256 _progress) internal {
        if (!currentChallenge.completed && block.timestamp <= currentChallenge.deadline) {
            currentChallenge.currentProgress += _progress;
            if (currentChallenge.currentProgress >= currentChallenge.goal) {
                currentChallenge.completed = true;
                distributeCommunityReward();
            }
        }
    }

    function distributeCommunityReward() internal {
        require(currentChallenge.completed, "Challenge not completed");
        require(advertisements.length > 0, "No participants");

        uint256 rewardPerParticipant = currentChallenge.reward / advertisements.length;
        uint256 maxDistributions = advertisements.length > 50 ? 50 : advertisements.length;

        for (uint256 i = 0; i < maxDistributions; i++) {
            adToken.mint(advertisements[i].advertiser, rewardPerParticipant);
        }
    }

    // ========== SPECIAL EVENTS ==========

    function startSpecialEvent(string memory _name, uint256 _duration, uint256 _rewardMultiplier)
        public
        onlyRole(ADMIN_ROLE)
        validString(_name)
    {
        require(_duration > 0, "Duration must be positive");
        require(_rewardMultiplier >= 100, "Multiplier must be at least 100");

        currentEvent = SpecialEvent(_name, block.timestamp, block.timestamp + _duration, _rewardMultiplier);

        emit SpecialEventStarted(_name, block.timestamp, block.timestamp + _duration, _rewardMultiplier);
    }

    function isSpecialEventActive() public view returns (bool) {
        return block.timestamp >= currentEvent.startTime && block.timestamp <= currentEvent.endTime;
    }

    function getEventRewardMultiplier() public view returns (uint256) {
        return isSpecialEventActive() ? currentEvent.rewardMultiplier : 100;
    }

    // ========== ADMIN FUNCTIONS ==========

    function pauseContract() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpauseContract() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function withdraw() public onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(msg.sender).transfer(balance);
        emit WithdrawCompleted(msg.sender, balance);
    }

    function withdrawTokens() public onlyRole(ADMIN_ROLE) {
        uint256 contractBalance = adToken.balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");
        require(adToken.transfer(msg.sender, contractBalance), "Transfer failed");
    }

    function recoverErc20(address _tokenAddress, uint256 _amount)
        public
        onlyRole(ADMIN_ROLE)
        validAddress(_tokenAddress)
    {
        require(_tokenAddress != address(adToken), "Cannot recover the main token");
        require(IERC20(_tokenAddress).transfer(msg.sender, _amount), "Transfer failed");
        emit TokensRecovered(_tokenAddress, msg.sender, _amount);
    }

    // ========== VIEW FUNCTIONS ==========

    function getUserCreatedAds(address _user) public view returns (Advertisement[] memory) {
        uint256[] memory adIndices = userCreatedAds[_user];
        Advertisement[] memory ads = new Advertisement[](adIndices.length);

        for (uint256 i = 0; i < adIndices.length; i++) {
            ads[i] = advertisements[adIndices[i]];
        }

        return ads;
    }

    function getCurrentAd()
        public
        view
        returns (string memory, string memory, uint256, address, address, bool, uint256)
    {
        require(advertisements.length > 0, "No advertisements yet");
        for (int256 i = int256(advertisements.length) - 1; i >= 0; i--) {
            if (advertisements[uint256(i)].isActive) {
                Advertisement memory ad = advertisements[uint256(i)];
                return (ad.link, ad.imageUrl, ad.price, ad.advertiser, ad.referrer, ad.isActive, ad.engagements);
            }
        }
        revert("No active advertisements");
    }

    function getNextAdPrice() public view returns (uint256) {
        if (advertisements.length == 0) {
            return INITIAL_PRICE.unwrap();
        }
        UD60x18 price = INITIAL_PRICE.mul(PRICE_MULTIPLIER.pow(ud(advertisements.length)));
        return price.unwrap();
    }

    function getAdTokenBalance(address _address) public view returns (uint256) {
        return adToken.balanceOf(_address);
    }

    function hasAdvertised(address _address) public view returns (bool) {
        return advertisers[_address].hasAdvertised;
    }

    function getAdvertiserLevel(address _advertiser) public view returns (uint256) {
        return advertisers[_advertiser].level;
    }

    function getAdvertiserTotalEngagements(address _advertiser) public view returns (uint256) {
        return advertisers[_advertiser].totalEngagements;
    }

    function getUserEngagements(address _user) public view returns (uint256[] memory) {
        return userEngagements[_user];
    }

    function getMultipleAds(uint256[] memory _indices) public view returns (Advertisement[] memory) {
        require(_indices.length <= 100, "Too many indices requested");
        Advertisement[] memory result = new Advertisement[](_indices.length);
        for (uint256 i = 0; i < _indices.length; i++) {
            require(_indices[i] < advertisements.length, "Invalid advertisement index");
            result[i] = advertisements[_indices[i]];
        }
        return result;
    }

    function getTotalAds() public view returns (uint256) {
        return advertisements.length;
    }

    function getActiveAds(uint256 _offset, uint256 _limit) public view returns (Advertisement[] memory, uint256) {
        require(_limit <= 100, "Limit too high");

        uint256 activeCount = 0;
        for (uint256 i = 0; i < advertisements.length; i++) {
            if (advertisements[i].isActive) {
                activeCount++;
            }
        }

        uint256 start = _offset > activeCount ? activeCount : _offset;
        uint256 end = start + _limit > activeCount ? activeCount : start + _limit;
        uint256 resultSize = end - start;

        Advertisement[] memory activeAds = new Advertisement[](resultSize);
        uint256 index = 0;
        uint256 count = 0;

        for (uint256 i = 0; i < advertisements.length && index < resultSize; i++) {
            if (advertisements[i].isActive) {
                if (count >= start) {
                    activeAds[index] = advertisements[i];
                    index++;
                }
                count++;
            }
        }

        return (activeAds, activeCount);
    }

    function getTimesAsChief(address _user) public view returns (uint256) {
        return timesAsChief[_user];
    }

    function getCurrentChief() public view returns (address, uint256, uint256) {
        return (chefOfAdvertising, adToken.balanceOf(chefOfAdvertising), getAdvertiserLevel(chefOfAdvertising));
    }

    function getAdvertiserInfo(address _advertiser)
        public
        view
        returns (bool, uint256, uint256, uint256, uint256, uint256)
    {
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

    function hasUnlockedAchievement(address _user, uint256 _achievementId) public view returns (bool) {
        require(_achievementId < achievements.length, "Invalid achievement ID");
        return userAchievements[_user][_achievementId];
    }

    function getCurrentChallengeInfo() public view returns (string memory, uint256, uint256, uint256, uint256, bool) {
        return (
            currentChallenge.description,
            currentChallenge.goal,
            currentChallenge.currentProgress,
            currentChallenge.reward,
            currentChallenge.deadline,
            currentChallenge.completed
        );
    }

    function getCurrentEventInfo() public view returns (string memory, uint256, uint256, uint256) {
        return (currentEvent.name, currentEvent.startTime, currentEvent.endTime, currentEvent.rewardMultiplier);
    }

    function getUserEngagedAds(address _user, uint256 _offset, uint256 _limit)
        public
        view
        returns (Advertisement[] memory, uint256)
    {
        require(_limit <= 100, "Limit too high");

        uint256[] memory engagedIndices = userEngagements[_user];
        uint256 total = engagedIndices.length;

        uint256 start = _offset > total ? total : _offset;
        uint256 end = start + _limit > total ? total : start + _limit;
        uint256 resultSize = end - start;

        Advertisement[] memory engagedAds = new Advertisement[](resultSize);

        for (uint256 i = 0; i < resultSize; i++) {
            engagedAds[i] = advertisements[engagedIndices[start + i]];
        }

        return (engagedAds, total);
    }

    function getUserReferralInfo(address _user) public view returns (address, address[] memory) {
        return (referrers[_user], referrals[_user]);
    }

    function getUserAchievementProgress(address _user) public view returns (bool[] memory) {
        bool[] memory unlockedAchievements = new bool[](achievements.length);

        for (uint256 i = 0; i < achievements.length; i++) {
            unlockedAchievements[i] = userAchievements[_user][i];
        }

        return unlockedAchievements;
    }

    function getUserChallengeParticipation(address _user) public view returns (bool) {
        for (uint256 i = 0; i < advertisements.length; i++) {
            if (advertisements[i].advertiser == _user) {
                return true;
            }
        }
        return false;
    }

    function getUserEventParticipation(address _user) public view returns (bool) {
        if (isSpecialEventActive()) {
            for (uint256 i = 0; i < advertisements.length; i++) {
                if (
                    advertisements[i].advertiser == _user && advertisements[i].createdAt >= currentEvent.startTime
                        && advertisements[i].createdAt <= currentEvent.endTime
                ) {
                    return true;
                }
            }
        }
        return false;
    }

    function getUserStats(address _user)
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

    function getWeeklyEngagements(address _user) public view returns (uint256) {
        return weeklyEngagementsByEpoch[currentWeekEpoch][_user];
    }
}
