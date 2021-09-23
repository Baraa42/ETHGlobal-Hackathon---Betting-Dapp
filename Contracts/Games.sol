// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract Games {

    address  public admin;
    uint gameId;
    Game game;
    uint [] odds;
    uint backBetId;
    uint LayBetId;

    mapping(Selection => mapping(uint => Bet [])) backBets;  //  Selection => Odds => back bets
    mapping(Selection => mapping(uint => Bet [])) layBets;  //  Selection =>Odds => lay bets  
    mapping(Selection => mapping(uint => uint)) backBetsAvailable; // tracks amount of back bet availble : Selection => Odds => amount
    mapping(Selection => mapping(uint => uint)) layBetsAvailable;// tracks amount of lay bet availble :  Selection => Odds => amount
    mapping(Selection => mapping(uint => uint)) firstIdofBackBetAvailable; // track Id of first back bet available,  Selection => Odds => Id
    mapping(Selection => mapping(uint => uint)) firstIdofLayBetAvailable; // track Id of first lay bet available,  Selection => Odds => Id
    mapping(address => mapping(Selection => uint)) playerPayout;

    enum BetType {Back, Lay}
    enum Selection {Open, Home, Draw, Away}
    enum GameStatus {Open, Over}
    enum BetStatus {Unmachted, Matched, Closed, Win, Lose}

   
    event NewStatus();
    event GameWinner(Selection selection);
    event unmatchedBetCreated(address _player, uint256 _odds, Selection _selection, BetType _betType);
    event betMatched(address _backer, address _layer, uint odds, Selection _selection);

    struct Game {
        address owner;
        uint kickOff;
        string teams;
        GameStatus status;
        Selection winner;

    }

    struct Bet {
        address payable player;
        BetType betType;
        Selection selection;
        //uint stake; gonna assume only 1 ether bet allowed
        uint odds;
        BetStatus status;
       
    }

     // Check if caller is the admin
    modifier isAdmin(address addr) {
        require(addr==admin, "you are not allowed");
        _;

    }
    // Check if the selection of the bet is correct 
    modifier isValidBet(Selection selection) {
        require(selection != Selection.Open, "not a valid bet");
        _;
    }
    // check if the game is over
    modifier isOver() {
        require(game.status == GameStatus.Over ,"game is not over");
        _;
    }
    // check if the game has already started
    modifier isStarted(uint date) {
        require(date < game.kickOff, "game already started");
        _;
    }
    // check if game is still open
    modifier isOpen() {
        require(game.status == GameStatus.Open, "Game is Over");
        _;
    }

    modifier isUnmatched(Bet memory bet) {
        require(bet.status == BetStatus.Unmachted, "Cant add already matched bet ");
        _;
    }

    modifier isValidStake(BetType betType, uint _odds) {
        if (betType == BetType.Back){
            require(msg.value == 1 ether, "not right stake");
        }
        else if (betType == BetType.Lay) {
            uint amount = 1 ether * ( _odds -1);
            require(msg.value == amount, "not right stake");

        }
        _;
    }


    constructor(uint kickOff, string memory teams) public {
        require(kickOff > block.timestamp +1 minutes);
        admin = msg.sender;
        game.kickOff = kickOff;
        game.owner = admin;
        game.teams = teams;
        game.status = GameStatus.Open;
        game.winner = Selection.Open;
        for(uint i=101; i<201; i++) {
            odds.push(i);

        }
        for(uint i=1; i<51; i++) {
            odds.push(200+2*i);
        }
        for(uint i=1; i<71;i++) {
            odds.push(300+10*i);
        }
        for(uint i=1;i<21;i++) {
            odds.push(1000+50*i);
        }
        for(uint i=1; i<81;i++) {
            odds.push(2000+100*i);
        }


    }
      
// admin change game status
   function changeGameStatus( Selection winner) public isAdmin(msg.sender) isOpen() returns(bool) {
        game.status = GameStatus.Over;
        game.winner = winner;
        
        emit GameWinner( winner);
        
        return true;



    }

    function placeBet(BetType _betType, Selection _selection, uint _odds) public payable isValidStake(_betType, _odds) isValidBet(_selection) isStarted(block.timestamp)  {

         

        if(_betType == BetType.Back){

            uint betId = backBets[_selection][_odds].length;
            Bet memory playerBet = Bet(payable(msg.sender), _betType, _selection, _odds, BetStatus.Unmachted);
            backBets[_selection][_odds].push(playerBet);

            // Check if possible to match the bet
            if (layBetsAvailable[_selection][_odds]>0) {
                uint layId = firstIdofLayBetAvailable[_selection][_odds];
                backBets[_selection][_odds][betId].status = BetStatus.Matched;
                layBets[_selection][_odds][layId].status = BetStatus.Matched;
                layBetsAvailable[_selection][_odds]-=1;
                address payable layPlayer = layBets[_selection][_odds][layId].player;
                incrementPotentialPayout(payable(msg.sender), _odds,  _selection, BetType.Back);
                incrementPotentialPayout(layPlayer, _odds,  _selection, BetType.Lay);
                firstIdofLayBetAvailable[_selection][_odds]+=1;
                emit betMatched(msg.sender, layPlayer,  _odds,  _selection);
                

            
            }
           

            else if (layBetsAvailable[_selection][_odds] == 0) {
                layBetsAvailable[_selection][_odds]+=1;
                emit unmatchedBetCreated(msg.sender,  _odds,  _selection,  _betType);
            }
            

                
            
        }

        else if (_betType == BetType.Lay) {
            uint betId = layBets[_selection][_odds].length;
            Bet memory playerBet = Bet(payable(msg.sender), _betType, _selection, _odds, BetStatus.Unmachted);
            layBets[_selection][_odds].push(playerBet);

            // Check if possible to match the bet
            if (backBetsAvailable[_selection][_odds]>0) {
                uint backId = firstIdofBackBetAvailable[_selection][_odds];
                backBets[_selection][_odds][backId].status = BetStatus.Matched;
                layBets[_selection][_odds][betId].status = BetStatus.Matched;
                backBetsAvailable[_selection][_odds]-=1;
                address payable backPlayer = backBets[_selection][_odds][backId].player;
                incrementPotentialPayout(payable(msg.sender), _odds,  _selection, BetType.Lay);
                incrementPotentialPayout(backPlayer, _odds,  _selection, BetType.Back);
                firstIdofBackBetAvailable[_selection][_odds]+=1;
                emit betMatched(backPlayer, msg.sender,  _odds,  _selection);
                

            
            }
           

            else if (backBetsAvailable[_selection][_odds] == 0) {
                backBetsAvailable[_selection][_odds]+=1;
                emit unmatchedBetCreated(msg.sender,  _odds,  _selection,  _betType);
            }
            
        }
        
        


    }




// increments the playerPayout of the player after a bet
    function incrementPotentialPayout(address payable _player, uint _odds, Selection _selection, BetType _betType) internal {
        if (_betType == BetType.Back) {
            playerPayout[_player][_selection] += (_odds - 1)* 1 ether;
        }

        else if (_betType == BetType.Lay) {
            if(_selection == Selection.Home) {
                playerPayout[_player][Selection.Draw] += 1 ether;
                playerPayout[_player][Selection.Away] += 1 ether;
            }
            else if(_selection == Selection.Draw) {
                playerPayout[_player][Selection.Home] += 1 ether;
                playerPayout[_player][Selection.Away] += 1 ether;
            }
            else if(_selection == Selection.Away) {
                playerPayout[_player][Selection.Home] += 1 ether;
                playerPayout[_player][Selection.Draw] += 1 ether;
            }
        }
    }
    // player call payout to get paid
    function payout() public isOver() returns(bool) {
        address payable _player = payable(msg.sender);
        uint _payoutAmount;
        if (game.winner == Selection.Home){
            _payoutAmount = playerPayout[_player][Selection.Home];
            playerPayout[_player][Selection.Home] = 0;
            _player.transfer(_payoutAmount);
            return true;


        }

        else if (game.winner == Selection.Draw){
            _payoutAmount = playerPayout[_player][Selection.Draw];
            playerPayout[_player][Selection.Draw] = 0;
            _player.transfer(_payoutAmount);
            return true;


        }

        else if (game.winner == Selection.Away){
            _payoutAmount = playerPayout[_player][Selection.Away];
            playerPayout[_player][Selection.Away] = 0;
            _player.transfer(_payoutAmount);
            return true;


        }
        return false;

    }


  


}