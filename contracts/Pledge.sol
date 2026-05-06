// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract PledgeToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    IERC20 public targetToken;
    IUniswapV2Router02 public router;

    address[] public treasuries;
    uint256 public nextTreasuryIndex;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    struct PledgeInfo {
        uint256 amount;
        uint256 period;
        uint256 timestamp;
    }

    mapping(address => PledgeInfo[]) public userPledges;

    event Pledge(
        address indexed user,
        uint256 usdtAmount,
        uint256 treasuryAmount,
        uint256 swapAmount,
        uint256 burnedAmount,
        uint256 period,
        uint256 timestamp
    );
    event TreasuriesUpdated(address[] treasuries);

    constructor(address _usdt, address _targetToken, address _router) {
        require(
            _usdt != address(0) &&
                _targetToken != address(0) &&
                _router != address(0),
            "invalid address"
        );

        usdt = IERC20(_usdt);
        targetToken = IERC20(_targetToken);
        router = IUniswapV2Router02(_router);
    }

    function setTreasuries(address[] calldata _treasuries) external onlyOwner {
        require(_treasuries.length > 0, "empty treasuries");
        delete treasuries;
        for (uint256 i = 0; i < _treasuries.length; i++) {
            require(_treasuries[i] != address(0), "zero address");
            treasuries.push(_treasuries[i]);
        }
        nextTreasuryIndex = 0;
        emit TreasuriesUpdated(treasuries);
    }

    function getTreasuries() external view returns (address[] memory) {
        return treasuries;
    }

    function pledge(uint256 amount, uint256 period) external {
        require(amount >= 100 * 1e18, "Minimum pledge amount 100");
        require(period > 0, "invalid period");
        require(treasuries.length > 0, "no treasury");

        usdt.safeTransferFrom(msg.sender, address(this), amount);

        uint256 swapAmount = amount;

        usdt.safeApprove(address(router), 0);
        usdt.safeApprove(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(targetToken);

        uint256[] memory expected = router.getAmountsOut(swapAmount, path);
        uint256 minOut = (expected[1] * 95) / 100;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            minOut,
            path,
            address(this),
            block.timestamp + 600
        );

        uint256 received = amounts[1];
        uint256 burnedAmount = received / 2;
        uint256 treasuryAmount = received - burnedAmount;
        address treasury = treasuries[nextTreasuryIndex];
        nextTreasuryIndex = (nextTreasuryIndex + 1) % treasuries.length;
        
        targetToken.safeTransfer(treasury, treasuryAmount);
        targetToken.safeTransfer(DEAD, burnedAmount);

        userPledges[msg.sender].push(
            PledgeInfo({
                amount: amount,
                period: period,
                timestamp: block.timestamp
            })
        );

        emit Pledge(
            msg.sender,
            amount,
            treasuryAmount,
            swapAmount,
            burnedAmount,
            period,
            block.timestamp
        );
    }

    function rescueToken(
        address _token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "zero address");

        IERC20 t = IERC20(_token);
        uint256 bal = t.balanceOf(address(this));
        uint256 out = amount == 0 ? bal : amount;

        require(bal >= out, "insufficient");

        t.safeTransfer(to, out);
    }
}
