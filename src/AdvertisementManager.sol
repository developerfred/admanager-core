// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract AdvertisementManager {
    address public owner;    
    uint256 public constant INITIAL_PRICE = 300000000000000 wei;
    uint256 public constant PRICE_MULTIPLIER = 5;

    struct Advertisement {
        string link;
        string imageUrl;
        uint256 price;
    }

    Advertisement public currentAd;
    uint256 public adCounter;

    event NewAdvertisement(string link, string imageUrl, uint256 price);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }

    function createAdvertisement(string memory _link, string memory _imageUrl) public payable {
        uint256 requiredPrice = getNextAdPrice();
        // This line checks if enough ETH was sent
        require(msg.value >= requiredPrice, "Insufficient payment for advertisement");

        currentAd = Advertisement(_link, _imageUrl, requiredPrice);
        adCounter++;

        emit NewAdvertisement(_link, _imageUrl, requiredPrice);
    }

    function getCurrentAd() public view returns (string memory, string memory, uint256) {
        return (currentAd.link, currentAd.imageUrl, currentAd.price);
    }

    // Use this function to check the price before creating an ad
    function getNextAdPrice() public view returns (uint256) {
        if (adCounter == 0) {
            return INITIAL_PRICE; // First ad costs 0.0003 ETH
        }
        // Subsequent ads increase in price
        return INITIAL_PRICE * (PRICE_MULTIPLIER ** adCounter);
    }
}