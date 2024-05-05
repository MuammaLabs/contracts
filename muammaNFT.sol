// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./muammaToken.sol";

contract MuammaNFT is ERC721, ERC721URIStorage, AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Properties {
        uint32 factorX;
        uint16 level;
        uint8 charge;
    }

    mapping(uint256 => Properties) public properties;

    event FactorXUpdated(
        address userAddress,
        uint256 indexed tokenId,
        uint32 newFactorX
    );
    event NftMinted(
        address ownerNft,
        uint256 indexed tokenId,
        Properties properties
    );
    event Charged(address userAddress, uint256 indexed tokenId, uint32 charge);
    event InitalNftPriceChanged(uint32 newInitialPrice);
    event ReChargePriceChanged(uint32 newReChargePrice);
    event LevelUpdated(uint256 tokenId, uint16 newLevel);
    event RewardMinted(address userAddress, uint256 tokenId, uint256 amount);
    event ChargeConsumed(
        address userAddress,
        uint256 indexed tokenId,
        uint8 newDecreasedCharge
    );
    event ChargeTransfered(
        address from,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint8 amount
    );

    address public TOKEN_BANK;

    uint32 private constant _factorX = 10**5; // 100000, initial X value: 1.00000
    uint8 private constant _level = 1;
    uint8 private constant _charge = 20;
    uint32 public baseReChargePrice = 80; // Maximum tokens earned from a question of the quiz
    uint32 public nftPrice = 2000;
    uint32 private constant MIN_FACTORX = 100000;
    uint32 private constant MAX_FACTORX = 999999;

    uint256 private decimal = 10**8;

    MuammaToken private immutable _muammaToken;

    Counters.Counter public _tokenIdCounter;

    constructor(
        address mmaTokenAddress,
        address superAdmin,
        address tokenBank,
        address firstAdmin
    ) ERC721("Muamma NFT", "MNFT") {
        _muammaToken = MuammaToken(mmaTokenAddress);
        TOKEN_BANK = tokenBank;
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(ADMIN_ROLE, firstAdmin);
    }

    function updateReChargePrice(uint32 newChargePrice)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseReChargePrice = newChargePrice;
        emit ReChargePriceChanged(baseReChargePrice);
    }

    function updateNftPrice(uint32 newInitialPrice)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        nftPrice = newInitialPrice;
        emit InitalNftPriceChanged(newInitialPrice);
    }

    function changeTokenBank(address newTokenBank)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        TOKEN_BANK = newTokenBank;
    }

    function safeMint(string memory tokenUri)
        public
        checkBalance(msg.sender, nftPrice)
        nonReentrant
    {
        _muammaToken.transferFrom(msg.sender, TOKEN_BANK, nftPrice * decimal);

        uint256 tokenId = _tokenIdCounter.current();

        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);

        properties[tokenId] = Properties({
            factorX: _factorX,
            level: _level,
            charge: _charge
        });

        _setTokenURI(tokenId, tokenUri);

        emit NftMinted(msg.sender, tokenId, properties[tokenId]);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function levelUp(uint256 tokenId, address userAddress)
        external
        checkUserHasNFT(userAddress)
        isOwner(userAddress, tokenId)
        onlyRole(ADMIN_ROLE)
    {
        properties[tokenId].level++;
        emit LevelUpdated(tokenId, properties[tokenId].level);
    }

    function decreaseCharge(uint256 tokenId)
        public
        checkUserHasNFT(msg.sender)
        isOwner(msg.sender, tokenId)
    {
        require(properties[tokenId].charge > 0, "Charge value 0");
        properties[tokenId].charge--;

        emit ChargeConsumed(msg.sender, tokenId, properties[tokenId].charge);
    }

    function chargeTransfer(
        address fromAddress,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint8 chargeAmount
    )
        public
        isOwner(fromAddress, fromTokenId)
        checkLevelForChargeTransfer(fromTokenId, toTokenId)
        checkUserHasNFT(fromAddress)
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        require(
            properties[fromTokenId].charge - chargeAmount >= 0,
            "Charge value cannot be below 0"
        );
        require(
            properties[toTokenId].charge + chargeAmount <= 20,
            "Charge value cannot be above 20"
        );

        properties[fromTokenId].charge -= chargeAmount;
        properties[toTokenId].charge += chargeAmount;

        emit ChargeTransfered(
            fromAddress,
            fromTokenId,
            toTokenId,
            chargeAmount
        );
    }

    function chargeNFT(uint256 tokenId, uint8 chargeAmount)
        public
        checkBalance(
            msg.sender,
            (properties[tokenId].factorX * baseReChargePrice *
                chargeAmount)  / _factorX
        )
        nonReentrant
    {
        require(properties[tokenId].charge < 20, "Your NFT already charged");
        require(
            properties[tokenId].charge + chargeAmount <= 20,
            "Charge amount cannot exceed 20"
        );
        uint256 amount = (properties[tokenId].factorX *
            baseReChargePrice *
            chargeAmount *
            decimal) / _factorX;

        _muammaToken.burnFrom(msg.sender, amount);
        properties[tokenId].charge += chargeAmount;

        emit Charged(msg.sender, tokenId, properties[tokenId].charge);
    }

    function mintReward(
        uint256 tokenId,
        address userAddress,
        uint256 rewardAmount
    )
        external
        onlyRole(ADMIN_ROLE)
        checkUserHasNFT(userAddress)
        isOwner(userAddress, tokenId)
        nonReentrant
    {
        _muammaToken.mint(userAddress, rewardAmount);
        emit RewardMinted(userAddress, tokenId, rewardAmount);
    }

    function updateFactorX(
        uint256 tokenId,
        address userAddress,
        uint32 updatedFactorX
    )
        external
        onlyRole(ADMIN_ROLE)
        isOwner(userAddress, tokenId)
        checkUserHasNFT(userAddress)
    {
        if (updatedFactorX < MIN_FACTORX || updatedFactorX > MAX_FACTORX) {
            revert InvalidFactorX(updatedFactorX, userAddress, tokenId);
        }
        properties[tokenId].factorX = updatedFactorX;
        emit FactorXUpdated(userAddress, tokenId, updatedFactorX);
    }

    modifier checkLevelForChargeTransfer(
        uint256 fromTokenId,
        uint256 toTokenId
    ) {
        require(
            properties[fromTokenId].level == properties[toTokenId].level,
            "Level does not match"
        );
        _;
    }

    modifier checkUserHasNFT(address from) {
        require(balanceOf(from) > 0, "You dont have an NFT.");
        _;
    }

    modifier checkBalance(address userAddress, uint32 balance) {
        require(
            _muammaToken.balanceOf(userAddress) >= balance * decimal,
            "Insufficient balance."
        );
        _;
    }

    modifier isOwner(address userAddress, uint256 tokenId) {
        require(ownerOf(tokenId) == userAddress, "You are not owner.");
        _;
    }

    error InvalidFactorX(uint32 sendedFactorX, address from, uint256 tokenId);
}
