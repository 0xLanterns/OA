# OA    | Learn to find vulnerabilities and write POC's

Sharpen your smart contract auditing skills with this Training Ground - a platform to practice identifying vulnerabilities discovered in audit contests and crafting high-quality proof of concepts.

[![Twitter Follow](https://img.shields.io/twitter/follow/Kiki_developer?label=Follow%20Kiki%20%40Kiki_developer&style=social)](https://twitter.com/Kiki_developer)
[![Twitter Follow](https://img.shields.io/twitter/follow/ZoumanaCisse6?label=Follow%20Zouvier%20%40ZoumanaCisse6&style=social)](https://twitter.com/ZoumanaCisse6)

Visit [0xLanterns](https://0xlanterns.vercel.app/)

### Shout-Out
- This platform is 1000% inspired by [Tincho](https://twitter.com/tinchoabbate) and [Nicolás](https://twitter.com/ngp2311).
    - Tincho made [Damn Vulnerable Defi](https://www.damnvulnerabledefi.xyz) which is a great wargame to learn offensive security and improve as a security researcher! 
    - Nicolás made [damn-vulnerable-defi-foundry](https://github.com/nicolasgarcia214/damn-vulnerable-defi-foundry). He was able to recreate Damn Vulnerable in Foundry!

### Acknowledgement 
- All of the levels are snippets from real protocols. Their teams are the ones that built the codebases and went the extra (necessary) mile of getting an Audit by one of the premiere auditing platforms. 

#### What is OA?
- OA is a place for auditors practice finding contest level vulnerabilities and writing quality POC's that illustrate the impact the vulnerabilities can have. All levels here are directly from past contest on both Code4ena and Sherlock. The idea here is that by simplifying the codebase and the testing framework, and providing a vulnerability with different tiers of hints. We can somewhat flatten the learning curve for developing an auditor's intuition and how to write good reports. Which center around a good POC. 

## How To Play 

1.  **Install Foundry**

First run the command below to get foundryup, the Foundry toolchain installer:

``` bash
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your PATH, run it to get the latest forge and cast binaries:

``` console
foundryup
```

2. **Clone This Repo and install dependencies**
``` 
git clone https://github.com/0xLanterns/OA.git
cd OA
forge install
```
3. **Code your solutions in the provided `[NAME_OF_THE_LEVEL].t.sol` files (inside each level's folder in the test folder)**
4. ** Only edit the test file where you see the following:
```Solidity
        /**
                poc can go here
         */
```
5. **Run your POC for the level, In each test file you will see something like:
```Solidity
// Run:  forge test --match-test testPOC0
```
If the test is executed successfully, then you have just created a working POC!!!
### Resources
- The Foundry Book will become your best friend. Tons of great documentation on how to navigate testing in Foundry. [Foundry Book](https://book.getfoundry.sh/).

### Disclaimer
- All Solidity code, practices, and patterns in this repository are from unaudited codebases. All vulnerabilities have since been resolved. The protocol's codebases look drastically different and improved now. The code here should not be a reflection of their protocol as it was intentionally not production-ready.

- This platform is strictly to be used for educational purposes.
**DO NOT USE IN PRODUCTION.**
