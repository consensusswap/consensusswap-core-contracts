/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@&#G5J?7!~~~::::::::::::::::~^^^:::::^:G@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@#GY7~:.                                    5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@#P?^.                                          5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@#Y!.                    ~????????????????????????7B@@@@@@@@@@@@@
@@@@@@@@@@@@@&P!.                       5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@&Y:                          5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@&Y:                      .::^~^7YYYYYYYYYYYYYYYYYYYYYYYYY#@@@@@@@@@@@@@
@@@@@@@@P:                  .^7YPB#&@@@&.                         5@@@@@@@@@@@@@
@@@@@@&7                 :?P#@@@@@@@@@@&.                         5@@@@@@@@@@@@@
@@@@@B:               .7G&@@@@@@@@@&#BBP.                         5@@@@@@@@@@@@@
@@@@G.              .J#@@@@@@@&GJ!^:.                             5@@@@@@@@@@@@@
@@@G.              7#@@@@@@#5~.                                   5@@@@@@@@@@@@@
@@#.             :P@@@@@@#?.                                      5@@@@@@@@@@@@@
@@~             :#@@@@@@J.       .~JPGBBBBBBBBBBBBBBBBBBBBBBBBBBBB&@@@@@@@@@@@@@
@5             .#@@@@@&~       !P&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@~             P@@@@@&^      ^G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
B             ~@@@@@@7      ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
5             5@@@@@#      .#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Y   ..     .. P#####5      7@@@@@@@@@@@@@@@@@@@@@@@@&##########################&
@############B:    .       !@@@@@@@@@@@@@@@@@@@@@@@@5            ..            7
@@@@@@@@@@@@@@:            .#@@@@@@@@@@@@@@@@@@@@@@@~                          7
@@@@@@@@@@@@@@J             ~&@@@@@@@@@@@@@@@@@@@@@?       ......              5
@@@@@@@@@@@@@@#.             ^G@@@@@@@@@@@@@@@@@@#!      .G#####G.            .#
@@@@@@@@@@@@@@@P               !P&@@@@@@@@@@@@@G7.      :G@@@@@@~             ?@
@@@@@@@@@@@@@@@@5                :!JPG####BPY7:        7#@@@@@&!             :#@
@@@@@@@@@@@@@@@@@P:                   ....           !B@@@@@@#~              P@@
@@@@@@@@@@@@@@@@@@#!                             .^J#@@@@@@@Y.              J@@@
@@@@@@@@@@@@@@@@@@@@G~                      .^!JP#@@@@@@@&5^               Y@@@@
@@@@@@@@@@@@@@@@@@@@@@G7.               ?BB#&@@@@@@@@@@#J:                5@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@&P7:            5@@@@@@@@@@&GJ~.                ^B@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@B5?~:.      5@@@@&#G5?~.                  .Y@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#BGP5YJ~~~^^..                      ?#@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                         .?B@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                       ^Y&@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                    ^JB@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                :!5#@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.         ..^!JP#@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&~::^~!7?5PB&@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./ConsensusERC20.sol";
import "./UQ112x112.sol";
import "../interfaces/IConsensusPair.sol";
import "../interfaces/IConsensusFactory.sol";

contract ConsensusPair is ConsensusERC20, IConsensusPair {
  using UQ112x112 for uint224;

  event Mint(address indexed sender, uint256 amount0, uint256 amount1);
  event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint256 amount0In,
    uint256 amount1In,
    uint256 amount0Out,
    uint256 amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
  bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

  address public factory;
  address public token0;
  address public token1;

  uint112 private reserve0; // uses single storage slot, accessible via getReserves
  uint112 private reserve1; // uses single storage slot, accessible via getReserves
  uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

  uint256 public price0CumulativeLast;
  uint256 public price1CumulativeLast;
  uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

  uint32 public constant swapFee = 25; // 0.25% swap fee
  uint40 public constant devFee = 10; // 0.10% protocol fee

  uint256 private unlocked = 1;

  modifier lock() {
    require(unlocked == 1, "Consensus: locked");
    unlocked = 0;
    _;
    unlocked = 1;
  }

  function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
    _reserve0 = reserve0;
    _reserve1 = reserve1;
    _blockTimestampLast = blockTimestampLast;
  }

  constructor() {
    factory = msg.sender;
  }

  // called once by the factory at time of deployment
  function initialize(address _token0, address _token1, string memory name, string memory symbol) external {
    require(msg.sender == factory, "Consensus: forbidden"); // sufficient check
    token0 = _token0;
    token1 = _token1;
    _name = name;
    _symbol = symbol;
  }

  // this low-level function should be called from a contract which performs important safety checks
  function mint(address to) external lock returns (uint256 liquidity) {
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    uint256 balance0 = IERC20(token0).balanceOf(address(this));
    uint256 balance1 = IERC20(token1).balanceOf(address(this));
    uint256 amount0 = balance0 - _reserve0;
    uint256 amount1 = balance1 - _reserve1;

    uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
    if (_totalSupply == 0) {
      liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
      _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
    } else {
      liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
    }
    require(liquidity > 0, "Consensus: insufficient_liquidity_minted");
    _mint(to, liquidity);

    _update(balance0, balance1, _reserve0, _reserve1);
    emit Mint(msg.sender, amount0, amount1);
  }

  // this low-level function should be called from a contract which performs important safety checks
  function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    address _token0 = token0; // gas savings
    address _token1 = token1; // gas savings
    uint256 balance0 = IERC20(_token0).balanceOf(address(this));
    uint256 balance1 = IERC20(_token1).balanceOf(address(this));
    uint256 liquidity = balanceOf[address(this)];
    uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee

    amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
    amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
    require(amount0 > 0 && amount1 > 0, "Consensus: insufficient_liquidity_burned");
    _burn(address(this), liquidity);
    _safeTransfer(_token0, to, amount0);
    _safeTransfer(_token1, to, amount1);
    balance0 = IERC20(_token0).balanceOf(address(this));
    balance1 = IERC20(_token1).balanceOf(address(this));

    _update(balance0, balance1, _reserve0, _reserve1);
    emit Burn(msg.sender, amount0, amount1, to);
  }

  // this low-level function should be called from a contract which performs important safety checks
  function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata) external lock {
    require(amount0Out > 0 || amount1Out > 0, "Consensus: insufficient_output_amount");
    (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    require(amount0Out < _reserve0 && amount1Out < _reserve1, "Consensus: insufficient_liquidity");

    uint256 amount0In;
    uint256 amount1In;
    address _token0 = token0;
    address _token1 = token1;
    {
      require(to != _token0 && to != _token1, "Consensus: invalid_to");
      if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
      if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
      uint256 balance0 = IERC20(_token0).balanceOf(address(this));
      uint256 balance1 = IERC20(_token1).balanceOf(address(this));
      amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
      amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
      require(amount0In > 0 || amount1In > 0, "Consensus: insufficient_input_amount");

      uint256 _swapFee = swapFee;
      // scope for reserve{0,1}Adjusted, avoids stack too deep errors
      uint256 balance0Adjusted = balance0 * 10000 - amount0In * _swapFee;
      uint256 balance1Adjusted = balance1 * 10000 - amount1In * _swapFee;
      require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * (10000 ** 2), "Consensus: K");
    }

    {
      uint256 _devFee = devFee;
      address feeTo = IConsensusFactory(factory).feeTo();
      uint256 _fee0 = amount0In * _devFee / 10000;
      uint256 _fee1 = amount1In * _devFee / 10000;
      if (_fee0 > 0) _safeTransfer(_token0, feeTo, _fee0);
      if (_fee1 > 0) _safeTransfer(_token1, feeTo, _fee1);
    }

    _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), _reserve0, _reserve1);
    emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
  }

  // force balances to match reserves
  function skim(address to) external lock {
    address _token0 = token0; // gas savings
    address _token1 = token1; // gas savings
    _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
    _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
  }

  // force reserves to match balances
  function sync() external lock {
    _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
  }

  function _safeTransfer(address token, address to, uint256 value) private {
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "Consensus: transfer_failed");
  }

  // update reserves and, on the first call per block, price accumulators
  function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
    require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Consensus: overflow");
    uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
    uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
    if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
      // * never overflows, and + overflow is desired
      price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
      price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
    }
    reserve0 = uint112(balance0);
    reserve1 = uint112(balance1);
    blockTimestampLast = blockTimestamp;
    emit Sync(reserve0, reserve1);
  }

  // Take dev fee
  function _takeFee(uint256 _amount0In, uint256 _amount1In) internal {}
}

/*
@@@@@@@@@@@@@@@@@@@@@@@@@@@@&#G5J?7!~~~::::::::::::::::~^^^:::::^:G@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@#GY7~:.                                    5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@#P?^.                                          5@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@#Y!.                    ~????????????????????????7B@@@@@@@@@@@@@
@@@@@@@@@@@@@&P!.                       5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@&Y:                          5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@&Y:                      .::^~^7YYYYYYYYYYYYYYYYYYYYYYYYY#@@@@@@@@@@@@@
@@@@@@@@P:                  .^7YPB#&@@@&.                         5@@@@@@@@@@@@@
@@@@@@&7                 :?P#@@@@@@@@@@&.                         5@@@@@@@@@@@@@
@@@@@B:               .7G&@@@@@@@@@&#BBP.                         5@@@@@@@@@@@@@
@@@@G.              .J#@@@@@@@&GJ!^:.                             5@@@@@@@@@@@@@
@@@G.              7#@@@@@@#5~.                                   5@@@@@@@@@@@@@
@@#.             :P@@@@@@#?.                                      5@@@@@@@@@@@@@
@@~             :#@@@@@@J.       .~JPGBBBBBBBBBBBBBBBBBBBBBBBBBBBB&@@@@@@@@@@@@@
@5             .#@@@@@&~       !P&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@~             P@@@@@&^      ^G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
B             ~@@@@@@7      ^&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
5             5@@@@@#      .#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Y   ..     .. P#####5      7@@@@@@@@@@@@@@@@@@@@@@@@&##########################&
@############B:    .       !@@@@@@@@@@@@@@@@@@@@@@@@5            ..            7
@@@@@@@@@@@@@@:            .#@@@@@@@@@@@@@@@@@@@@@@@~                          7
@@@@@@@@@@@@@@J             ~&@@@@@@@@@@@@@@@@@@@@@?       ......              5
@@@@@@@@@@@@@@#.             ^G@@@@@@@@@@@@@@@@@@#!      .G#####G.            .#
@@@@@@@@@@@@@@@P               !P&@@@@@@@@@@@@@G7.      :G@@@@@@~             ?@
@@@@@@@@@@@@@@@@5                :!JPG####BPY7:        7#@@@@@&!             :#@
@@@@@@@@@@@@@@@@@P:                   ....           !B@@@@@@#~              P@@
@@@@@@@@@@@@@@@@@@#!                             .^J#@@@@@@@Y.              J@@@
@@@@@@@@@@@@@@@@@@@@G~                      .^!JP#@@@@@@@&5^               Y@@@@
@@@@@@@@@@@@@@@@@@@@@@G7.               ?BB#&@@@@@@@@@@#J:                5@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@&P7:            5@@@@@@@@@@&GJ~.                ^B@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@B5?~:.      5@@@@&#G5?~.                  .Y@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#BGP5YJ~~~^^..                      ?#@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                         .?B@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                       ^Y&@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                    ^JB@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.                :!5#@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&.         ..^!JP#@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&~::^~!7?5PB&@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/
