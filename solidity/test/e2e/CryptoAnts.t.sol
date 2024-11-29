// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import {Test} from 'forge-std/Test.sol';
import {CryptoAnts, ICryptoAnts} from 'contracts/CryptoAnts.sol';
import {Egg} from 'contracts/Egg.sol';
import {IEgg} from 'contracts/Egg.sol';
import {TestUtils} from 'test/TestUtils.sol';
import {console} from 'forge-std/console.sol';

contract E2ECryptoAnts is Test,TestUtils {
     uint256 internal constant FORK_BLOCK = 17_052_487;
    ICryptoAnts internal _cryptoAnts;
    address internal _owner = makeAddr('owner');
    ICryptoAnts internal _cryptoAnts;
    IEgg internal _eggs;

    function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    _eggs = new Egg();
    _cryptoAnts = new CryptoAnts(address(_eggs));
     _eggs.setAnts(address(_cryptoAnts));
  }

    function testOnlyAllowCryptoAntsToMintEggs() public {
     vm.expectRevert("Only the ants contract can call this function, please refer to the ants contract");
     _eggs.mint(address(this),1 * 1e18);
    }

    function testBuyAnEggAndCreateNewAnt() public {
            uint256 initialBalance = address(this).balance();
            _cryptoAnts.buyEggs{value: 0.001 ether}(1 ether);
            uint256 finalBalance = address(this).balance();
            assertLt(finalBalance , initialBalance, "Egg purchase failed");

            _cryptoAnts.createAnt();
            uint256 antId = _cryptoAnts.getAntsCreated();
            assertEq(antId, 1, "Ant creation failed");

            address antOwner = _cryptoAnts.ownerOf(antId);
            assertEq(antOwner, address(this), "Ant ownership failed");
        
    }

    function testSendFundsToTheUserWhoSellsAnts() public {
        
            _cryptoAnts.createAnt();
            uint256 initialBalance = address(this).balance();

            _cryptoAnts.sellAnt(1);

            uint256 finalBalance = address(this).balance();
            assertGt(finalBalance, initialBalance, "Funds not sent after selling ant");
        
    }

    function testBurnTheAntAfterTheUserSellsIt() public {
            _cryptoAnts.createAnt();
            _cryptoAnts.sellAnt(2);
            address antOwner = _cryptoAnts.ownerOf(2);
            assertEq(antOwner, address(0), "Ant not burned after selling");
        
    }

    function testBeAbleToCreate100AntsWithOnlyOneInitialEgg() public {
            uint256 initialAntsCreated = _cryptoAnts.getAntsCreated();

            // Create 100 ants
            for (uint256 i = 0; i < 100; i++) {
                // Create an ant
                _cryptoAnts.createAnt();

                // Wrap the transaction and wait for confirmation
                vm.wrap(block.timestamp + 60);

                console.log("Ant ", i + 1, " created");
            }

            uint256 finalAntsCreated = _cryptoAnts.getAntsCreated();

            // Verify that 100 ants are created
            assertEq(finalAntsCreated,initialAntsCreated +100,"finaAnstsCreated should be equal to initialAntsCreated incremented by 100");
    
    }
}
