// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Functions, FunctionsClient} from "../dev/functions/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error AgreementAlreadySigned();
error ProjectDoesNotExist();

contract CommunityEngine is FunctionsClient, ConfirmedOwner {
  using Functions for Functions.Request;
  using SafeERC20 for IERC20;

  struct Project {
    address owner;
    address kol;
    address tokenAddress;
    uint256 numTokensToPayout;
    bool isComplete;
    bool kolHasAgreed;
    bool exists;
    string tweet;
  }

  struct Agreement {
    address owner;
    string projectName;
  }

  bytes32 public latestRequestId;
  bytes public latestResponse;
  bytes public latestError;

  /// @notice A KOL's list of signed agreements with project owners.
  mapping(address => Agreement[]) public kolAgreements;

  //// @notice A project owner's projects.
  mapping(address => mapping(string => Project)) public projects;

  event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

  constructor(address oracle) FunctionsClient(oracle) ConfirmedOwner(msg.sender) {}

  /// @notice Add a new project for a KOL to be a part of.
  function addProject(
    string memory projectName,
    address kol,
    address tokenAddress,
    uint256 numTokensToPayout
  ) external {
    require(numTokensToPayout > 0, "payment must be greater than 0");

    // deposit tokens into contract
    IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), numTokensToPayout);

    projects[msg.sender][projectName] = Project({
      owner: msg.sender,
      kol: kol,
      tokenAddress: tokenAddress,
      numTokensToPayout: numTokensToPayout,
      isComplete: false,
      kolHasAgreed: false,
      exists: true,
      tweet: ""
    });
  }

  /// @notice Allows for a KOL of a project to activate project.
  function signAgreement(string memory projectName, string memory tweet) external {
    Project storage project = projects[msg.sender][projectName];
    if (!project.exists) {
      revert ProjectDoesNotExist();
    }
    if (project.kolHasAgreed) {
      revert AgreementAlreadySigned();
    }

    kolAgreements[msg.sender].push(Agreement({owner: project.owner, projectName: projectName}));

    project.kolHasAgreed = true;
    project.tweet = tweet;
  }

  function getKOLProjects(address account) external view returns (Project[] memory) {
    Agreement[] memory agreements = kolAgreements[account];
    Project[] memory kolProjects = new Project[](agreements.length);

    for (uint256 i = 0; i < agreements.length; i++) {
      Project memory project = projects[agreements[i].owner][agreements[i].projectName];
      kolProjects[i] = project;
    }

    return kolProjects;
  }

  /**
   * @notice Send a simple request
   *
   * @param source JavaScript source code
   * @param secrets Encrypted secrets payload
   * @param args List of arguments accessible from within the source code
   * @param subscriptionId Billing ID
   * @param gasLimit Maximum amount of gas used to call the client contract's `handleOracleFulfillment` function
   * @return Functions request ID
   */
  function executeRequest(
    string calldata source,
    bytes calldata secrets,
    string[] calldata args, // args in sequence are: ArtistID, artistname,  lastListenerCount, artist email
    uint64 subscriptionId,
    uint32 gasLimit
  ) public onlyOwner returns (bytes32) {
    Functions.Request memory req;
    req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);

    if (secrets.length > 0) {
      req.addRemoteSecrets(secrets);
    }
    if (args.length > 0) {
      req.addArgs(args);
    }

    // Update storage variables.
    bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
    latestRequestId = assignedReqID;
    //latestArtistRequestedId = args[0];
    return assignedReqID;
  }

  /**
   * @notice Callback that is invoked once the DON has resolved the request or hit an error
   *
   * @param requestId The request ID, returned by sendRequest()
   * @param response Aggregated response from the user code
   * @param err Aggregated error from the user code or from the execution pipeline
   * Either response or error parameter will be set, but never both
   */
  function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
    latestResponse = response;
    latestError = err;
    emit OCRResponse(requestId, response, err);

    // Artist contract for payment logic here.
    // Artist gets a fixed rate for every addition 1000 active monthly listeners.
    bool nilErr = (err.length == 0);
    if (nilErr) {
      // string memory artistId = latestArtistRequestedId;
      // (int256 latestListenerCount, int256 diffListenerCount) = abi.decode(response, (int256, int256));
      // if (diffListenerCount <= 0) {
      //     // No payments due.
      //     return;
      // }
      // // Pay the artist at 'artistData[latestArtistRequestedId].walletAddress'.
      // uint8 stcDecimals = IStableCoin(s_stc).decimals();
      // // Artist gets 1 STC per  10000 additional streams.
      // uint256 amountDue = (uint256(diffListenerCount) * 1 * 10 ** stcDecimals) / 10000;
      // // TODO @Zubin disable solhint
      // // console.log("\nAmount Due To Artist: ", amountDue);
      // payArtist(artistId, amountDue);
      // // Update Artist Mapping.
      // artistData[artistId].lastListenerCount = uint256(latestListenerCount);
      // artistData[artistId].lastPaidAmount = amountDue;
      // artistData[artistId].totalPaid += amountDue;
    }
  }

  function updateOracleAddress(address oracle) public onlyOwner {
    setOracle(oracle);
  }

  function addSimulatedRequestId(address oracleAddress, bytes32 requestId) public onlyOwner {
    addExternalRequest(oracleAddress, requestId);
  }

  function payKOL(string memory projectName) private {}
}
