// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MuammaToken is ERC20, ERC20Burnable, AccessControl {
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public burn_count = 0;

    uint public constant INITIAL_SUPPLY = 50000000;
    
    uint private constant DECIMAL = 10**8 ; // 100000000



    function decimals() public pure override returns(uint8)  {
        return 8;
    }

    constructor(address superAdmin, address firstAdmin) ERC20("Muamma Token", "MMA") {
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
        _grantRole(ADMIN_ROLE, firstAdmin);
        _mint(msg.sender, INITIAL_SUPPLY * DECIMAL); // mint initial supply to contract creator
    }

    function mint(address to, uint256 amount) public onlyRole(ADMIN_ROLE){
        super._mint(to, amount);
        emit Minted(amount);
    }

    function burn(uint256 amount) public override  {
        super._burn(msg.sender, amount);
        burn_count += amount;
        emit Burned(amount);
    }

    function burnFrom(address account, uint256 amount) public override {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        super._burn(account, amount);
        burn_count += amount;
        emit Burned(amount);
    }



    function mintQuestionCreator(address account, uint256 amount) public onlyRole(ADMIN_ROLE) {
        super._mint(account, amount);

        emit MintedForQuestionCreator(account,amount);
    }

    event MintedForQuestionCreator(address account, uint256 amount);
    event Burned(uint256 amount);
    event Minted(uint256 amount);
}
