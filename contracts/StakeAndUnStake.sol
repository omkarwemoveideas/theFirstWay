// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function ceil(uint256 a, uint256 m) internal pure returns (uint256 r) {
        return ((a + m - 1) / m) * m;
    }
}

contract SushiBar is ERC20("SushiBar", "xSUSHI"), KeeperCompatibleInterface {
    using SafeMath for uint256;
    IERC20 public sushi;
    uint256 public _startTimestamp;
    // Token amount variables
    mapping(address => uint256) public alreadyWithdrawn;
    mapping(address => uint256) private balances;

    constructor(IERC20 _sushi) {
        sushi = _sushi;
        _startTimestamp = block.timestamp;
    }

    // Enter the bar. Pay some SUSHIs. Earn some shares.
    // Locks Sushi and mints xSushi
    function enter(uint256 _amount) public {
        // Gets the amount of Sushi locked in the contract
        uint256 totalSushi = sushi.balanceOf(address(this));
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        // If no xSushi exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalSushi == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xSushi the Sushi is worth. The ratio will change overtime, as xSushi is burned/minted and Sushi deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalSushi);
            _mint(msg.sender, what);
        }
        // Lock the Sushi in the contract
        sushi.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your SUSHIs.
    // Unclocks the staked + gained Sushi and burns xSushi
    function leave(uint256 _share) public {
        // Gets the amount of xSushi in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Sushi the xSushi is worth
        uint256 what = _share.mul(sushi.balanceOf(address(this))).div(
            totalShares
        );
        _burn(msg.sender, _share);
        alreadyWithdrawn[msg.sender] = alreadyWithdrawn[msg.sender].add(what);
        sushi.transfer(msg.sender, what);
    }

    function taxTokens(
        address to,
        uint256 tokens,
        uint8 tax
    ) public {
        require(address(to) != address(0), "Invalid address");
        require(
            balances[msg.sender] >= tokens,
            "insufficient sender's balance"
        );

        balances[msg.sender] = balances[msg.sender].sub(tokens);
        uint256 deduction = 0;

        deduction = onePercent(tokens).mul(tax); // Calculates the tax to be applied on the amount transferred
        uint256 _OS = onePercent(deduction).mul(10); // 10% will go to owner
        balances[msg.sender] = balances[msg.sender].add(deduction.sub(_OS)); // add the tax deducted to the staking pool for rewards
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 currState = block.timestamp;

        if (
            currState == _startTimestamp &&
            currState <= _startTimestamp * 2 days
        ) {
            upkeepNeeded = true;
        } else if (
            currState > _startTimestamp * 2 days &&
            currState < _startTimestamp * 4 days
        ) {
            upkeepNeeded = true;
        } else if (
            currState > _startTimestamp * 4 days &&
            currState < _startTimestamp * 6 days
        ) {
            upkeepNeeded = true;
        } else if (
            currState > _startTimestamp * 6 days &&
            currState < _startTimestamp * 8 days
        ) {
            upkeepNeeded = true;
        } else if (currState >= _startTimestamp * 8 days) {
            upkeepNeeded = true;
        } else {
            upkeepNeeded = false;
        }
        performData = checkData;
    }

    /**
     * @dev once checkUpKeep been triggered, keeper will call performUpKeep
     **/
    function performUpkeep(bytes calldata performData) external override {
        uint256 currState = block.timestamp;

        if (
            currState == _startTimestamp &&
            currState <= _startTimestamp * 2 days
        ) {
            leave(0);
        } else if (
            currState > _startTimestamp * 2 days &&
            currState < _startTimestamp * 4 days
        ) {
            leave(25);
        } else if (
            currState > _startTimestamp * 4 days &&
            currState < _startTimestamp * 6 days
        ) {
            leave(50);
        } else if (
            currState > _startTimestamp * 6 days &&
            currState < _startTimestamp * 8 days
        ) {
            leave(75);
        } else if (currState >= _startTimestamp * 8 days) {
            leave(75);
        }

        performData;
    }

    function onePercent(uint256 _tokens) internal pure returns (uint256) {
        uint256 roundValue = _tokens.ceil(100);
        uint256 onePercentofTokens = roundValue.mul(100).div(
            100 * 10**uint256(2)
        );
        return onePercentofTokens;
    }
}
