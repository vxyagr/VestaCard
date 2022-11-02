// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "contracts/ERC20Callback.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestaToken is ERC20Callback, Ownable {
    address vestaCard;
    constructor(address to, uint256 amount) ERC20Callback("VESTA", "VST") {
        _mint(to, (amount));
    }

    function setVestaCard(address _addr) public onlyOwner{
        vestaCard=_addr;
    }
 
    function mint(address to, uint256 amount) public  {
        require(msg.sender==owner()||msg.sender==vestaCard,"access not allowed");
        _mint(to, amount);

    }

}