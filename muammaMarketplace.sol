// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./muammaToken.sol";
import "./muammaNFT.sol";

contract MuammaMarketplace is ReentrancyGuard{
    struct Listing {
        address seller;
        uint256 price;
        uint256 tokenId;
    }

    address public ADMIN;
    address public ADMIN_2; 
    uint8 public feePercent = 3; // %3

    MuammaNFT immutable private nftContract;
    MuammaToken immutable private paymentToken;

    mapping(uint256 => Listing) public listings;

    event Listed(uint256 tokenId, uint256 price);
    event Delisted(uint256 tokenId);
    event Purchased(uint256 tokenId, address buyer, uint256 price);

    constructor(
        address _nftContract,
        address _paymentToken,
        address admin2
    ) {
        nftContract = MuammaNFT(_nftContract);
        paymentToken = MuammaToken(_paymentToken);
        ADMIN = msg.sender;
        ADMIN_2 = admin2;
    }

    function listNFT(uint256 tokenId, uint256 price) external nonReentrant {
        require(
            nftContract.ownerOf(tokenId) == msg.sender,
            "You must own the NFT to list it."
        );
        if (price <= 0) {
            revert InvalidListPrice(msg.sender, tokenId);
        }
        nftContract.transferFrom(msg.sender, address(this), tokenId); // Transfer NFT to this contract
        listings[tokenId] = Listing(msg.sender, price, tokenId);

        emit Listed(tokenId, price);
    }

    function delistNFT(uint256 tokenId) external nonReentrant {
        require(
            listings[tokenId].seller == msg.sender,
            "You are not the seller."
        );

        nftContract.transferFrom(address(this), msg.sender, tokenId); // Transfer NFT back to seller
        delete listings[tokenId];

        emit Delisted(tokenId);
    }

    function buyNFT(uint256 tokenId) external nonReentrant{
        require(
            listings[tokenId].seller != address(0),
            "Listing does not exist."
        );

        require(listings[tokenId].seller != msg.sender, "You are owner.");

        Listing memory listing = listings[tokenId];

        require(
            paymentToken.balanceOf(msg.sender) >= listing.price,
            "Insufficient balance."
        );

        uint256 fee = (listing.price * feePercent) / 100;
        uint256 amountAfterFee = listing.price - fee;

        paymentToken.transferFrom(msg.sender, listing.seller, amountAfterFee); // Transfer payment tokens to seller
        paymentToken.burnFrom(msg.sender, fee); // Burn fees

        nftContract.transferFrom(address(this), msg.sender, tokenId); // Transfer NFT to buyer

        delete listings[tokenId];

        emit Purchased(tokenId, msg.sender, listing.price);
    }

    function updateFeePercent(uint8 updatedFeePercent) public {
        require(
            msg.sender == ADMIN || msg.sender == ADMIN_2,
            "Only admin can perform this action."
        );
        feePercent = updatedFeePercent;
    }

    error InvalidListPrice(address from, uint256 tokenId);
}
