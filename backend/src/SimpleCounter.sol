// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract SimpleCounter {

    uint256 public count;
    event Incremented(uint256 newCount);

    function increment() public {
        count++;
        emit Incremented(count);
    }
}