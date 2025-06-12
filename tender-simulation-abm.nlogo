;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TENDER SIMULATION PROCESS ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GLOBAL VARIABLES AND CONSTANTS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [stats]

globals [
  ;; Simulation state
  id-active-tender
  winning-bids-list

  ;; Configuration constants (initialized in setup)
  MIN-QUALITY
  MAX-QUALITY
  BASE-TENDER-VALUE
  TENDER-VALUE-VARIANCE

  ;; Experience thresholds
  EXPERIENCE-THRESHOLD-LOW
  EXPERIENCE-THRESHOLD-HIGH

  ;; Quality-price ratio thresholds
  THRESHOLD-HIGH-MAX
  THRESHOLD-HIGH-MIN
  THRESHOLD-MED-MAX
  THRESHOLD-MED-MIN
  THRESHOLD-LOW-MAX
  THRESHOLD-LOW-MIN

  ;; Data collection variables
  market-statistics
  round-statistics


  ;; Economic modeling constants
  MIN-PROFIT-MARGIN     ; 15%
  MAX-PROFIT-MARGIN     ; 40%
  TENDER-COMPLEXITY-DISCOUNT  ; margin reduction factor for complex tenders
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; AGENT BREEDS AND PROPERTIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

breed [tenders tender]
breed [evaluators evaluator]
breed [players player]

tenders-own [
  id
  value
  tender-type        ; "small", "medium", "large"
  complexity-factor  ; affects quality requirements
  winner
  bids
  estimated-cost     ; estimated cost to complete tender
]

evaluators-own [
  attitude
  rates-list
  expertise-level    ; affects evaluation consistency
  ;; Individual evaluator thresholds (personalized from global defaults)
  eval-threshold-high-max
  eval-threshold-high-min
  eval-threshold-med-max
  eval-threshold-med-min
  eval-threshold-low-max
  eval-threshold-low-min
]

players-own [
  ;; Core attributes
  experience
  base-quality       ; inherent firm quality capability
  current-quality    ; quality offered in current bid (varies)
  risk-attitude

  ;; Bidding behavior and strategy
  my-bid
  ideal-bid          ; The bid calculated for profit before competitive adjustments
  bid-strategy
  bid-adjustment     ; corrective action based on bid-to-winning ratio
  bidding-archetype  ; "aggressive", "conservative", "adaptive", "follower"
  strategy-confidence ; how confident player is in their current strategy
  player-id          ; Stable ID for visualization, avoiding 'who' issues

  ;; Learning and memory
  history-bids
  history-qualities    ; track quality history for recent rounds
  winner?
  win-count
  total-bids

  ;; Enhanced metrics
  profitability      ; track estimated profit margins
  market-position    ; competitive standing

  ;; Social learning and market intelligence
  observed-strategies    ; strategies observed from other players
  social-influence       ; susceptibility to social learning
  market-knowledge       ; partial information about market conditions
  learning-partners      ; list of players this agent learns from
  strategy-adaptation-rate ; how quickly player adapts strategy
  competitive-response   ; reaction to competitive pressure
  strategy-imitation-cooldown

  ;; Performance tracking
  recent-performance     ; performance over last N rounds
  performance-trend      ; improving, stable, or declining
  market-share          ; estimated market share
  overall-performance-metric ; Combined metric for win-rate and profitability

  ;; Economic modeling and profit targeting
  target-profit-margin   ; desired profit margin (15-40%)
  current-profit-margin  ; actual achieved margin
  cost-estimation-accuracy ; how well player estimates costs (0.0-1.0)
  profit-history         ; list of actual profit margins achieved
  margin-adjustment-rate ; how quickly player adjusts profit targets
  risk-premium          ; additional margin required for risk tolerance
  learning-curve-speed  ; how fast this player learns (0.1-1.0)
  market-intelligence   ; limited knowledge: own bids, tender values, winner bids
  tender-cost-estimates ; estimates of what tenders should cost
  margin-sensitivity    ; how sensitive margins are to tender complexity
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MAIN SIMULATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  initialize-globals
  build-players
  build-evaluators
  initialize-data-collection
  initialize-plots

  ; Set up circular market visualization
  ; Players are arranged in a circle, evaluators are hidden
  ; Tender will appear in center when simulation starts
  display-visualization-legend

  reset-ticks
end

to display-visualization-legend
  ; Display helpful information about the circular market visualization
  output-print "=================="
  output-print "CIRCULAR MARKET VISUALIZATION"
  output-print "=================="
  output-print "• Players arranged in circle around market center"
  output-print "• Player colors: Red=Aggressive, Blue=Conservative, Orange=Adaptive, Yellow=Follower"
  output-print "• Player size increases with market share"
  output-print "• Winners become stars and move closer to center"
  output-print "• Tender appears in center with type-based colors:"
  output-print "  - Green = Small tenders"
  output-print "  - Orange = Medium tenders"
  output-print "  - Red = Large tenders"
  output-print "• Player labels show current bids"
  output-print "=================="
end

to simulate-n-rounds
  repeat number-rounds [go]
  finalize-statistics
end

to go
  if ticks >= number-rounds [stop]
  simulate-tender
  make-bids
  evaluate-winner

  ; Apply social learning before strategy updates
  apply-social-learning

  update-strategies
  collect-round-data

  update-performance-tracking

  update-player-visualization

  ; Update plots with current round data
  refresh-plots

  tick
end

to update-player-visualization
  ; Update player appearance based on performance and market dynamics
  ask players [
    ; Update size based on market share (1.0 to 3.5 scale)
    let size-factor 1.0 + (market-share * 5)  ; minimum 1.0, scales with market share
    if size-factor > 3.5 [ set size-factor 3.5 ]  ; cap at 3.5
    set size size-factor

    ; Update position slightly based on performance (winners move closer to center)
    let base-angle (360 / number-players) * player-id
    let performance-factor market-position - 0.5  ; -0.5 to 1.5 range
    let radius-adjustment performance-factor * 2   ; ±2 units from base radius
    let new-radius 12 + radius-adjustment

    ; Ensure radius stays reasonable
    if new-radius < 6 [ set new-radius 6 ]
    if new-radius > 16 [ set new-radius 16 ]

    ; Calculate new position
    let x new-radius * cos base-angle
    let y new-radius * sin base-angle
    setxy x y

    ; Update label to show current bid (if participating)
    if my-bid > 0 [
      set label precision my-bid 1
    ]

    ; Highlight winner with different shape temporarily
    ifelse winner? [
      set shape "star"
      set size size-factor * 1.3  ; make winners slightly larger
    ] [
      set shape "person"
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INITIALIZATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to initialize-globals
  ;; Initialize simulation state
  set id-active-tender 0
  set winning-bids-list []
  set market-statistics []
  set round-statistics []

  ;; Initialize configuration constants
  set MIN-QUALITY 5
  set MAX-QUALITY 10
  set BASE-TENDER-VALUE 100
  set TENDER-VALUE-VARIANCE 0.3    ; 30% variance in tender values

  ;; Initialize experience thresholds
  set EXPERIENCE-THRESHOLD-LOW 5
  set EXPERIENCE-THRESHOLD-HIGH 10

  ;; Initialize quality-price ratio thresholds (based on realistic market ranges)
  set THRESHOLD-HIGH-MAX 0.2       ; max = (10/50 = 0.2)
  set THRESHOLD-HIGH-MIN 0.15
  set THRESHOLD-MED-MAX 0.15       ; medium threshold from 0.1 to 0.14
  set THRESHOLD-MED-MIN 0.1
  set THRESHOLD-LOW-MAX 0.1        ; low threshold from 0.05 to 0.09
  set THRESHOLD-LOW-MIN 0.05

  ;; Initialize economic modeling constants
  set MIN-PROFIT-MARGIN 0.15      ; 15% minimum profit margin
  set MAX-PROFIT-MARGIN 0.40      ; 40% maximum profit margin
  set TENDER-COMPLEXITY-DISCOUNT 0.05  ; 5% margin reduction per complexity unit

  ;; Validate and normalize MEAT criteria weights (sliders should sum to 1.0)
  let weight-sum meat-price-weight + meat-quality-weight + meat-experience-weight
  if abs(weight-sum - 1.0) > 0.01 [
    output-print (word "Warning: MEAT weights sum to " precision weight-sum 3 " instead of 1.0")
    output-print "Normalizing weights automatically for accurate evaluation"
    let normalization-factor 1.0 / weight-sum
    set meat-price-weight meat-price-weight * normalization-factor
    set meat-quality-weight meat-quality-weight * normalization-factor
    set meat-experience-weight meat-experience-weight * normalization-factor
    output-print (word "Normalized weights - Price: " precision meat-price-weight 3 ", Quality: " precision meat-quality-weight 3 ", Experience: " precision meat-experience-weight 3)
  ]
end

to initialize-data-collection
  ; Initialize tracking lists for enhanced metrics
  set market-statistics (list
    "round" "avg-bid" "min-bid" "max-bid" "bid-spread"
    "avg-quality" "winner-experience" "market-concentration"
  )
end

to build-evaluators
  create-evaluators 3 [
    set shape "person"
    set color red
    ; Hide evaluators from view - they work in background
    set hidden? true
    set attitude one-of ["extreme" "medium"]
    set expertise-level random-float 1.0  ; 0.0 to 1.0, affects evaluation consistency

    ; Set individual thresholds with some variation
    set eval-threshold-high-max THRESHOLD-HIGH-MAX + random-float 0.02 - 0.01
    set eval-threshold-high-min THRESHOLD-HIGH-MIN + random-float 0.02 - 0.01
    set eval-threshold-med-max THRESHOLD-MED-MAX + random-float 0.02 - 0.01
    set eval-threshold-med-min THRESHOLD-MED-MIN + random-float 0.02 - 0.01
    set eval-threshold-low-max THRESHOLD-LOW-MAX + random-float 0.02 - 0.01
    set eval-threshold-low-min THRESHOLD-LOW-MIN + random-float 0.02 - 0.01
  ]
end

to build-players
  create-players number-players [
  set shape "person"
  set color green
  ]

  ; Assign player-id separately to ensure it's contiguous from 0 to N-1
  ; This avoids issues with using non-contiguous 'who' numbers for calculations.
  let i 0
  foreach sort players [ p ->
    ask p [
      set player-id i

      ; Arrange players in a circle around the center
      let angle (360 / number-players) * player-id  ; Use stable player-id
      let radius 12  ; Distance from center
      let center-x 0
      let center-y 0

      ; Calculate circular position
      let x center-x + (radius * cos angle)
      let y center-y + (radius * sin angle)
      setxy x y

      ; Initialize core attributes
      set experience 1
      set base-quality MIN-QUALITY + ifelse-value (quality-base > 0) [random quality-base] [0] ; firm's inherent capability
      set bid-strategy (random 51) + 50  ; value between 50 and 100
      set risk-attitude 0
      set bid-adjustment 0
      calculate-risk-attitude

      ; Initialize tracking variables
      set history-bids []
      set history-qualities []
      set win-count 0
      set total-bids 0
      set profitability 0
      set market-position 0.5  ; neutral starting position

      ; Initialize bidding archetypes and social learning
      assign-bidding-archetype
      set strategy-confidence 0.5 + random-float 0.3  ; 0.5-0.8 initial confidence
      set observed-strategies []
      set social-influence 0.2 + random-float 0.6  ; 0.2-0.8 susceptibility to social learning
      set market-knowledge 0.1 + random-float 0.3  ; 0.1-0.4 initial market knowledge
      set learning-partners []
      set strategy-adaptation-rate 0.05 + random-float 0.15  ; 0.05-0.2 adaptation rate
      set competitive-response 0.3 + random-float 0.4  ; 0.3-0.7 competitive response
      set recent-performance []
      set performance-trend "stable"
      set market-share 1 / number-players  ; equal initial market share

      initialize-economic-attributes
    ]
    set i i + 1
  ]

  establish-learning-networks
end

to initialize-economic-attributes
  ; Initialize profit targeting and learning attributes
  set target-profit-margin MIN-PROFIT-MARGIN + random-float (MAX-PROFIT-MARGIN - MIN-PROFIT-MARGIN)
  set current-profit-margin 0
  set cost-estimation-accuracy 0.3 + random-float 0.5  ; 0.3-0.8 accuracy
  set profit-history []

  ; Learning curve speed - randomly distributed (some learn faster than others)
  ; Using exponential distribution to create realistic learning curve differences
  let random-factor random-float 1.0
  set learning-curve-speed 0.1 + (0.9 * (1 - exp (- random-factor * 2)))  ; 0.1-1.0, exponentially distributed

  set margin-adjustment-rate learning-curve-speed * 0.1  ; tied to learning speed

  ; Risk premium based on archetype
  if bidding-archetype = "aggressive" [
    set risk-premium 0.08 + random-float 0.04  ; 8-12% additional margin for profit maximization
  ]
  if bidding-archetype = "conservative" [
    set risk-premium 0.02 + random-float 0.03  ; 2-5% additional margin for market share focus
  ]
  if bidding-archetype = "adaptive" [
    set risk-premium 0.04 + random-float 0.04  ; 4-8% moderate risk premium
  ]
  if bidding-archetype = "follower" [
    set risk-premium 0.05 + random-float 0.03  ; 5-8% risk premium, follows others
  ]

  ; Market intelligence: limited knowledge
  set market-intelligence (list
    []                        ; own-bid-history (index 0)
    []                        ; tender-values (index 1)
    []                        ; winner-bids (index 2)
  )

  set tender-cost-estimates []

  ; Margin sensitivity to tender complexity (varies by player capability)
  set margin-sensitivity 0.5 + random-float 0.5  ; 0.5-1.0, how much margins shrink for complex tenders
end

to assign-bidding-archetype
  ; Assign bidding archetypes based on initial characteristics and realistic business behavior
  let archetype-prob random-float 1.0

  ifelse archetype-prob < 0.25 [
    set bidding-archetype "aggressive"
    set color red
    ; Aggressive = Profit maximizers, often high-quality providers
    set bid-strategy bid-strategy * 1.10  ; higher base strategy for premium pricing
    ; Bias towards higher quality for aggressive players (quality commands premium)
    if base-quality > (MIN-QUALITY + quality-base * 0.6) [
      set base-quality base-quality + random-float 1.0  ; quality boost for premium providers
    ]
  ] [
    ifelse archetype-prob < 0.5 [
      set bidding-archetype "conservative"
      set color blue
      ; Conservative = Market share focused, compete more on price
      set bid-strategy bid-strategy * 0.90  ; lower base strategy for competitive pricing
    ] [
      ifelse archetype-prob < 0.75 [
        set bidding-archetype "adaptive"
        set color orange
        ; Moderate base strategy, will adapt based on learning and market conditions
      ] [
        set bidding-archetype "follower"
        set color yellow
        set social-influence social-influence * 1.5  ; more susceptible to social learning
      ]
    ]
  ]
end

to establish-learning-networks
  ; Create learning partnerships between players
  ask players [
    ; Each player learns from 1-3 other players
    let num-partners 1 + random 3
    let potential-partners other players

    repeat num-partners [
      if any? potential-partners [
        let partner one-of potential-partners
        set learning-partners lput [player-id] of partner learning-partners
        set potential-partners potential-partners with [who != [who] of partner]
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SOCIAL LEARNING PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to apply-social-learning
  ; Players observe and learn from their learning partners
  ask players [
    ; Observe strategies of learning partners
    observe-partner-strategies

    ; Update market knowledge based on observations
    update-market-knowledge

    ; Consider strategy imitation if performance is poor
    consider-strategy-imitation

    ; Update archetype-specific behaviors
    update-archetype-behavior
  ]
end

to observe-partner-strategies
  ; Observe bidding strategies and outcomes of learning partners
  foreach learning-partners [ partner-id ->
    let partner one-of players with [player-id = partner-id]
    if partner != nobody [
      let partner-strategy [bid-strategy] of partner
      let partner-performance [overall-performance-metric] of partner
      let partner-archetype [bidding-archetype] of partner

      ; Store observation with decay (recent observations are more important)
      let observation (list partner-id partner-strategy partner-performance partner-archetype ticks)
      set observed-strategies lput observation observed-strategies

      ; Keep only recent observations (last 10 rounds)
      if length observed-strategies > 10 [
        set observed-strategies but-first observed-strategies
      ]
    ]
  ]
end

to update-market-knowledge
  ; Update understanding of market conditions based on observations
  if length observed-strategies > 0 [
    let avg-observed-strategy mean map [obs -> item 1 obs] observed-strategies
    let avg-observed-performance mean map [obs -> item 2 obs] observed-strategies

    ; Gradually update market knowledge
    let knowledge-update-rate market-intelligence-level * strategy-adaptation-rate
    set market-knowledge market-knowledge + (knowledge-update-rate * (avg-observed-performance - market-knowledge))

    ; Bounds checking
    if market-knowledge < 0 [ set market-knowledge 0 ]
    if market-knowledge > 1 [ set market-knowledge 1 ]

    ; Also learn from average observed bidding strategy
    let strategy-learning-rate market-intelligence-level * strategy-adaptation-rate
    set bid-strategy bid-strategy + (avg-observed-strategy - bid-strategy) * strategy-learning-rate
  ]
  ; Ensure market-intelligence lists are accessed safely
  let own-bid-data item 0 market-intelligence
  if length own-bid-data > 0 [
    ; Only perform operations if data exists
    ; Currently, no specific operation needed here, but structure ensures safety
  ]
  let tender-data item 1 market-intelligence
  if length tender-data > 0 [
    ; Only perform operations if data exists
  ]
  let winner-data item 2 market-intelligence
  if length winner-data > 0 [
    ; Only perform operations if data exists
  ]
end

to consider-strategy-imitation
  ; Consider imitating successful strategies if own performance is poor
  let my-performance overall-performance-metric

  if length observed-strategies > 0 [
    ; Find best performing observed strategy
    let best-performance max map [obs -> item 2 obs] observed-strategies
    let best-strategy-obs filter [obs -> item 2 obs = best-performance] observed-strategies

    if length best-strategy-obs > 0 [
      let best-obs one-of best-strategy-obs
      let best-strategy item 1 best-obs
      let best-archetype item 3 best-obs

      ; Consider imitation based on performance gap and social influence
      let performance-gap best-performance - my-performance
      let imitation-probability social-influence * performance-gap

      ; Check if player is in cooldown period for strategy imitation (minimum 3 rounds since last imitation)
      if not is-number? strategy-imitation-cooldown [ set strategy-imitation-cooldown -999 ]  ; Initialize if not set
      let rounds-since-last-imitation ticks - strategy-imitation-cooldown
      let cooldown-period 3  ; Minimum rounds before another imitation

      if imitation-probability > strategy-imitation-threshold and random-float 1.0 < imitation-probability and rounds-since-last-imitation >= cooldown-period [
        ; Imitate the successful strategy (partial imitation based on social influence)
        let strategy-adjustment (best-strategy - bid-strategy) * social-influence * social-learning-rate
        set bid-strategy bid-strategy + strategy-adjustment

        ; Update confidence based on imitation
        set strategy-confidence strategy-confidence * 0.9  ; reduce confidence when imitating

        ; Set cooldown to current tick
        set strategy-imitation-cooldown ticks

        output-print (sentence "Player" who "(" bidding-archetype ") imitates strategy from Player"
                      item 0 best-obs "(" best-archetype ")")
      ]
    ]
  ]
end

to update-archetype-behavior
  ; Update behavior based on archetype and market conditions
  let performance-trend-factor calculate-performance-trend

  if bidding-archetype = "aggressive" [
    ; Aggressive players are profit-maximizers: maintain high margins even under pressure
    if performance-trend-factor < 0 [
      ; Only modest reduction in margins when losing - they prefer fewer wins at good margins
      let adjustment-factor (0.99 - competitive-response * 0.01)
      ; Ensure adjustment factor is reasonable
      if adjustment-factor < 0.8 [ set adjustment-factor 0.8 ]
      if adjustment-factor > 1.2 [ set adjustment-factor 1.2 ]
      set bid-strategy bid-strategy * adjustment-factor
    ]
  ]

  if bidding-archetype = "conservative" [
    ; Conservative players are market-share focused: adjust pricing to maintain competitiveness
    let market-volatility calculate-market-volatility
    if market-volatility > 0.3 [
      ; When market is volatile, become more competitive to secure work
      let adjustment-factor (0.98 - market-volatility * 0.02)
      ; Ensure adjustment factor is reasonable
      if adjustment-factor < 0.5 [ set adjustment-factor 0.5 ]
      set bid-strategy bid-strategy * adjustment-factor
    ]
  ]

  if bidding-archetype = "adaptive" [
    ; Adaptive players adjust based on market trends
    ; Limit performance trend factor to prevent extreme adjustments
    if performance-trend-factor > 0.5 [ set performance-trend-factor 0.5 ]
    if performance-trend-factor < -0.5 [ set performance-trend-factor -0.5 ]

    let adjustment-factor (1 + performance-trend-factor * strategy-adaptation-rate)
    ; Ensure adjustment factor is reasonable
    if adjustment-factor < 0.5 [ set adjustment-factor 0.5 ]
    if adjustment-factor > 1.5 [ set adjustment-factor 1.5 ]
    set bid-strategy bid-strategy * adjustment-factor
  ]

  if bidding-archetype = "follower" [
    ; Followers heavily weight social learning
    if length observed-strategies > 2 [
      let social-strategy mean map [obs -> item 1 obs] observed-strategies
      let adjustment (social-strategy - bid-strategy) * social-influence * 0.3
      ; Limit adjustment to prevent extreme changes
      if adjustment > bid-strategy * 0.2 [ set adjustment bid-strategy * 0.2 ]
      if adjustment < bid-strategy * -0.2 [ set adjustment bid-strategy * -0.2 ]
      set bid-strategy bid-strategy + adjustment
    ]
  ]

  ; Apply global bounds to prevent bid-strategy from becoming too extreme
  if bid-strategy < 10 [ set bid-strategy 10 ]      ; minimum reasonable bid strategy
  if bid-strategy > 200 [ set bid-strategy 200 ]  ; maximum reasonable bid strategy
end

to-report calculate-performance-trend
  ; Calculate performance trend over recent rounds
  if length recent-performance > 2 and total-bids >= 5 [
    let recent-avg mean recent-performance
    let overall-avg 0
    set overall-avg win-count / total-bids
    report recent-avg - overall-avg
  ]
  report 0
end

to-report calculate-market-volatility
  ; Calculate market volatility based on bid spread variations
  if length round-statistics > 3 [
    let recent-spreads sublist (map [r -> item 4 r] round-statistics)
                               (max (list 0 (length round-statistics - 5)))
                               (length round-statistics)
    if length recent-spreads > 1 [
      let avg-spread mean recent-spreads
      if avg-spread > 0 [
        let spread-variance variance recent-spreads
        report spread-variance / avg-spread
      ]
    ]
  ]
  report 0.2  ; default moderate volatility
end

to update-performance-tracking
  ; Update performance tracking for all players
  ask players [
    ; Update recent performance (last 5 rounds)
    let current-round-performance ifelse-value (winner?) [1] [0]
    set recent-performance lput current-round-performance recent-performance

    if length recent-performance > 5 [
      set recent-performance but-first recent-performance
    ]

    ; Update performance trend
    if length recent-performance >= 3 [
      let recent-avg mean recent-performance
      let overall-performance ifelse-value (total-bids > 0) [win-count / total-bids] [0]

      if recent-avg > overall-performance + 0.1 [
        set performance-trend "improving"
      ]
      if recent-avg < overall-performance - 0.1 [
        set performance-trend "declining"
      ]
      if abs (recent-avg - overall-performance) <= 0.1 [
        set performance-trend "stable"
      ]
    ]

    ; Update market share based on recent wins across all players
    let total-recent-wins sum [sum recent-performance] of players
    if total-recent-wins > 0 [
      set market-share sum recent-performance / total-recent-wins
    ]

    ; Update strategy confidence based on performance
    if performance-trend = "improving" [
      set strategy-confidence min (list 1.0 (strategy-confidence + 0.05))
    ]
    if performance-trend = "declining" [
      set strategy-confidence max (list 0.1 (strategy-confidence - 0.05))
    ]

    ; Calculate overall performance metric, balancing win-rate and profitability
    let win-rate-component ifelse-value (total-bids > 0) [win-count / total-bids] [0]

    let profitability-component 0
    if length profit-history > 0 [
      let avg-profit mean profit-history
      ; Score profitability based on proximity to the target margin
      if target-profit-margin > 0 [
        set profitability-component (avg-profit / target-profit-margin)
        ; Cap reward for exceeding target to avoid rewarding overly conservative bidding
        if profitability-component > 1.2 [ set profitability-component 1.2 ]
        if profitability-component < 0 [ set profitability-component 0 ]
      ]
    ]

    ; Combine win-rate and profitability into a single performance metric.
    ; A weight of 0.5 balances win-rate and profitability.
    set overall-performance-metric (win-rate-component * 0.5) + (profitability-component * 0.5)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TENDER SIMULATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to simulate-tender
  ask tenders [die]

  ; Reset player shapes from previous round
  ask players [
    set shape "person"
    set label ""  ; Clear previous bid labels
  ]

  set id-active-tender id-active-tender + 1

  create-tenders 1 [
    set id id-active-tender
    set shape "target"  ; Changed from "flag" to "target" for market center
    set color lime     ; Bright color to stand out (will be overridden by tender type)
    set size 3         ; Default size (will be overridden by tender type)

    ; Position at market center
    setxy 0 0

    ; Variable tender values based on type and complexity
    generate-tender-characteristics
  ]
end

to generate-tender-characteristics
  ; Determine tender type and corresponding value
  let available-tender-types ["small" "medium" "large"]
  let type-weights [0.4 0.4 0.2]  ; 40% small, 40% medium, 20% large

  let random-val random-float 1.0
  ifelse random-val < 0.4 [
    set tender-type "small"
    set value BASE-TENDER-VALUE * (0.5 + random-float 0.5)  ; 50-100% of base
    set complexity-factor 0.7 + random-float 0.3  ; 0.7-1.0
    set color green   ; Small tenders are green
    set size 2.5
  ] [
    ifelse random-val < 0.8 [
      set tender-type "medium"
      set value BASE-TENDER-VALUE * (0.8 + random-float 0.4)  ; 80-120% of base
      set complexity-factor 0.8 + random-float 0.4  ; 0.8-1.2
      set color orange  ; Medium tenders are orange
      set size 3.0
    ] [
      set tender-type "large"
      set value BASE-TENDER-VALUE * (1.2 + random-float 0.8)  ; 120-200% of base
      set complexity-factor 1.0 + random-float 0.5  ; 1.0-1.5
      set color red     ; Large tenders are red
      set size 3.5
    ]
  ]

  ; Add random variance
  set value value * (1 + (random-float (2 * TENDER-VALUE-VARIANCE) - TENDER-VALUE-VARIANCE))
  set value precision value 2

  ; Estimate realistic cost to complete tender
  ; Cost should be 60-85% of tender value depending on complexity
  let base-cost-ratio 0.60 + (complexity-factor - 0.7) * 0.25  ; 0.60-0.85 ratio
  set estimated-cost value * base-cost-ratio
  set estimated-cost precision estimated-cost 2

  ; Update label with tender information, using precision for display only
  set label (word tender-type " (M$" precision value 2 ")")
  set label-color white
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BIDDING PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to make-bids
  let current-tender one-of tenders with [id = id-active-tender]
  let v [value] of current-tender
  let complexity [complexity-factor] of current-tender
  let actual-cost [estimated-cost] of current-tender

  output-print "=================="
  output-print "Bidding phase"
  output-print (word "Tender ID: " [id] of current-tender)
  output-print (word "Tender type: " [tender-type] of current-tender)
  output-print (word "Tender value: " v)
  output-print (word "Complexity factor: " precision complexity 2)
  output-print (word "Estimated cost: " actual-cost)
  output-print "=================="

  ask players [
    ; Enhanced quality modeling
    calculate-current-quality complexity

    ; Update market intelligence with current tender value directly
    let tender-data item 1 market-intelligence
    set tender-data lput v tender-data
    if length tender-data > 10 [
      set tender-data but-first tender-data
    ]
    set market-intelligence replace-item 1 market-intelligence tender-data

    ; Estimate tender cost based on player's capability and knowledge, passing tender value
    let my-cost-estimate estimate-tender-cost v complexity

    ; Calculate profit-margin-based bid
    calculate-profit-based-bid my-cost-estimate complexity
    set ideal-bid my-bid ; Store the ideal bid before adjustments

    ; Apply bidding strategy as a multiplier, connecting the social learning model to behavior.
    set my-bid my-bid * (bid-strategy / 100)

    ; Apply traditional risk attitude and adjustments
    apply-risk-adjustments

    ; Adjust bid to not exceed tender value based on market awareness
    ; Players inherently consider tender value as upper limit based on market knowledge
    let awareness-factor market-knowledge * 0.5 + 0.5  ; Ranges from 0.5 to 1.0 based on market knowledge
    if my-bid > v [
      let overbid-adjustment (my-bid - v) / my-bid  ; Proportion by which bid exceeds tender value
      set my-bid v * (1 - overbid-adjustment * (1 - awareness-factor))  ; Adjust bid down, more aware players adjust closer to tender value
      if my-bid <= 0 [ set my-bid 1 ]  ; Ensure minimum bid after adjustment
    ]

    ; Calculate and track actual profit margin based on estimated cost
    let estimated-profit-margin calculate-estimated-margin my-cost-estimate
    set current-profit-margin estimated-profit-margin

    ; Show bid as player label instead of creating links
    set label precision my-bid 1
    set label-color white

    ; Update tracking
    set total-bids total-bids + 1

    output-print (sentence "Player" player-id "bid" precision my-bid 2
                  "with quality" precision current-quality 1
                  "target margin" precision (target-profit-margin * 100) 1 "%"
                  "estimated margin" precision (estimated-profit-margin * 100) 1 "%")
  ]
end

to-report estimate-tender-cost [tender-value complexity]
  ; Players estimate cost based on their experience and cost estimation accuracy
  let base-cost-ratio 0.70  ; default baseline cost ratio
  let current-tender one-of tenders with [id = id-active-tender]
  let tender-type-val [tender-type] of current-tender

  ; Adjust base cost ratio based on tender type for realism (small tenders have higher relative costs, large have lower due to economies of scale)
  if tender-type-val = "small" [
    set base-cost-ratio 0.75 + random-float 0.10  ; 75-85% for small tenders (less economy of scale)
  ]
  if tender-type-val = "medium" [
    set base-cost-ratio 0.65 + random-float 0.10  ; 65-75% for medium tenders
  ]
  if tender-type-val = "large" [
    set base-cost-ratio 0.55 + random-float 0.10  ; 55-65% for large tenders (better economy of scale)
  ]

  let base-cost-estimate tender-value * base-cost-ratio  ; apply adjusted baseline

  ; Adjust for complexity
  let complexity-adjustment complexity * 0.05 * tender-value  ; more complex = higher cost

  ; Apply player's cost estimation accuracy (error factor)
  let estimation-error (1 - cost-estimation-accuracy) * 0.3  ; max 30% error
  let error-factor 1 + (random-float (2 * estimation-error) - estimation-error)

  let final-estimate (base-cost-estimate + complexity-adjustment) * error-factor

  ; Store cost estimate for learning
  set tender-cost-estimates lput final-estimate tender-cost-estimates
  if length tender-cost-estimates > 5 [
    set tender-cost-estimates but-first tender-cost-estimates
  ]

  report final-estimate
end

to calculate-profit-based-bid [cost-estimate complexity]
  ; Calculate bid based on desired profit margin, adjusted for tender complexity and risk

  ; Adjust target margin for tender complexity (larger/more complex = smaller margins)
  let complexity-adjustment 0
  let current-tender one-of tenders with [id = id-active-tender]
  let tender-type-val [tender-type] of current-tender

  if tender-type-val = "medium" [
    set complexity-adjustment TENDER-COMPLEXITY-DISCOUNT
  ]
  if tender-type-val = "large" [
    set complexity-adjustment TENDER-COMPLEXITY-DISCOUNT * 2
  ]

  ; Further adjust for specific complexity factor
  set complexity-adjustment complexity-adjustment + ((complexity - 1.0) * margin-sensitivity * TENDER-COMPLEXITY-DISCOUNT)

  ; Calculate adjusted target margin
  let adjusted-target-margin target-profit-margin - complexity-adjustment

  ; Apply risk premium based on archetype (realistic behavior: aggressive = profit-maximizers, conservative = market-share focused)
  if bidding-archetype = "aggressive" [
    ; Aggressive players are profit-maximizers: higher margins, fewer wins
    set adjusted-target-margin adjusted-target-margin + risk-premium
  ]
  if bidding-archetype = "conservative" [
    ; Conservative players are market-share focused: lower margins, more wins
    set adjusted-target-margin adjusted-target-margin - risk-premium
  ]

  ; Ensure margin stays within reasonable bounds
  if adjusted-target-margin < MIN-PROFIT-MARGIN [ set adjusted-target-margin MIN-PROFIT-MARGIN ]
  if adjusted-target-margin > MAX-PROFIT-MARGIN [ set adjusted-target-margin MAX-PROFIT-MARGIN ]

  ; Calculate base bid from cost and margin
  set my-bid cost-estimate / (1 - adjusted-target-margin)

  output-print (sentence "Player" player-id "cost estimate:" precision cost-estimate 2
                "adjusted margin target:" precision (adjusted-target-margin * 100) 1 "%"
                "base profit bid:" precision my-bid 2)
end

to apply-risk-adjustments
  ; Apply traditional risk attitude adjustments on top of profit-based bid
  let risk-factor 0
  let experience-factor experience / 20  ; small experience bonus/penalty

  ; Apply risk attitude (legacy system, but now as fine-tuning)
  if experience <= EXPERIENCE-THRESHOLD-LOW [
    set risk-factor (my-bid * risk-attitude * 0.5)
    set my-bid my-bid + risk-factor + experience-factor
  ]

  if experience > EXPERIENCE-THRESHOLD-LOW [
    set risk-factor (my-bid * risk-attitude * 0.5)  ; reduced impact
    set my-bid my-bid - risk-factor + experience-factor
  ]

  ; Apply bid adjustment from historical performance
  set my-bid my-bid * (1 + bid-adjustment)

  ; Add small random variation to represent market uncertainty
  set my-bid my-bid * (0.98 + random-float 0.04)  ; ±2% random variation
  set my-bid precision my-bid 2
end

to-report calculate-estimated-margin [cost-estimate]
  ; Calculate estimated profit margin based on bid and cost estimate
  if my-bid > 0 and cost-estimate > 0 [
    let margin (my-bid - cost-estimate) / my-bid
    if margin < 0 [ set margin 0 ]  ; no negative margins
    if margin > 1 [ set margin 1 ]  ; cap at 100%
    report margin
  ]
  report 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; EVALUATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to evaluate-winner
  output-print "=================="
  output-print "Evaluation phase"
  output-print (word "MEAT Criteria - Price: " (meat-price-weight * 100) "%, Quality: " (meat-quality-weight * 100) "%, Experience: " (meat-experience-weight * 100) "%")
  output-print "=================="

  let players-list sort-by [[p1 p2] -> [player-id] of p1 < [player-id] of p2] players with [my-bid > 0]

  ; Only proceed with evaluation if there are actual bidders
  if not empty? players-list [
    let bids-list []
    let players-exp []
    let quality-list []

    ; Collect player data for evaluation
    foreach players-list [
      player-agent ->
      if [my-bid] of player-agent > 0 [
        set bids-list lput [my-bid] of player-agent bids-list
        set players-exp lput [experience] of player-agent players-exp
        set quality-list lput ([current-quality] of player-agent) quality-list
      ]
    ]

    ; Calculate MEAT scores using weighted criteria
    let meat-scores calculate-meat-scores players-list bids-list quality-list players-exp

    ; Enhanced evaluator assessment with MEAT integration
    ask evaluators [
      set rates-list []
      foreach meat-scores [ meat-score ->
        let base-rating calculate-base-rating meat-score
        let final-rating apply-evaluator-bias base-rating
        set rates-list lput final-rating rates-list
      ]

      output-print (sentence "Evaluator" who "(" attitude ") MEAT-adjusted rates:"
                    map [r -> precision r 1] rates-list)
    ]

    output-print "=================="
    output-print "Final Decision"
    output-print "=================="

    ; Calculate final scores combining MEAT and evaluator assessments
    let total-scores []
    foreach players-list [
      player-agent ->
      let index position player-agent players-list
      let meat-score item index meat-scores
      let evaluator-score mean [item index rates-list] of evaluators
      let final-score (meat-score * 0.6) + (evaluator-score * 0.4)  ; 60% MEAT, 40% evaluator judgment
      set total-scores lput final-score total-scores

      output-print (sentence "Player" [who] of player-agent "- MEAT score:" precision meat-score 2
                    "Evaluator score:" precision evaluator-score 1
                    "Final score:" precision final-score 2)
    ]

    ; Determine winner(s)
    determine-winner players-list total-scores
  ]
end

to-report calculate-meat-scores [players-list bids-list quality-list experience-list]
  ; Calculate MEAT scores based on weighted criteria
  let meat-scores []

  ; Normalize each criterion (0-1 scale)
  let max-bid 0
  let min-bid 0
  if length bids-list > 0 [
    set max-bid max bids-list
    set min-bid min bids-list
  ]
  let current-max-quality 0
  let current-min-quality 0
  if length quality-list > 0 [
    set current-max-quality max quality-list
    set current-min-quality min quality-list
  ]
  let max-experience 0
  let min-experience 0
  if length experience-list > 0 [
    set max-experience max experience-list
    set min-experience min experience-list
  ]

  ; Normalize the MEAT weights themselves to ensure they sum to 1, preventing distorted scales.
  let weight-sum meat-price-weight + meat-quality-weight + meat-experience-weight
  if weight-sum = 0 [ set weight-sum 1 ] ; Avoid division by zero
  let norm-price-weight meat-price-weight / weight-sum
  let norm-quality-weight meat-quality-weight / weight-sum
  let norm-experience-weight meat-experience-weight / weight-sum

  foreach players-list [
    p ->
    let index position p players-list
    let bid item index bids-list
    let quality item index quality-list
    let player-exp item index experience-list

    ; Normalize scores (higher is better for all criteria)
    let price-score 0
    ifelse max-bid > min-bid [
      set price-score (max-bid - bid) / (max-bid - min-bid)  ; lower bid = higher score
    ] [
      set price-score 1 ; All bids are the same, give full score.
    ]

    let quality-score 0
    ifelse current-max-quality > current-min-quality [
      set quality-score (quality - current-min-quality) / (current-max-quality - current-min-quality)
    ] [
      set quality-score 1 ; All qualities are the same, give full score.
    ]

    let experience-score 0
    ifelse max-experience > min-experience [
      set experience-score (player-exp - min-experience) / (max-experience - min-experience)
    ] [
      set experience-score 1 ; All experiences are the same, give full score.
    ]

    ; Calculate weighted MEAT score using normalized weights
    let meat-score (price-score * norm-price-weight) +
                   (quality-score * norm-quality-weight) +
                   (experience-score * norm-experience-weight)

    set meat-scores lput meat-score meat-scores
  ]

  report meat-scores
end

to-report calculate-base-rating [meat-score]
  ; Convert MEAT score to evaluator rating scale (1-10)
  let base-rating 1 + (meat-score * 9)  ; scale 0-1 MEAT score to 1-10 rating
  report base-rating
end

to-report apply-evaluator-bias [base-rating]
  ; Apply evaluator-specific bias and expertise variation
  let rating base-rating

  ; Apply attitude bias
    if attitude = "extreme" [
    if base-rating > 7 [
      set rating rating * 1.2  ; amplify high scores
    ]
    if base-rating < 4 [
      set rating rating * 0.8  ; reduce low scores further
    ]
  ]

  ; Apply expertise variation
  let expertise-variation (1 - expertise-level) * 0.3 * rating
  set rating rating + (random-float (2 * expertise-variation) - expertise-variation)

  ; Ensure rating bounds
  if rating < 1 [ set rating 1 ]
  if rating > 10 [ set rating 10 ]

  report rating
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; WINNER DETERMINATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to determine-winner [players-list total-scores]
  if not empty? total-scores [
    let max-score max total-scores

    ; Correctly identify all players with the max score
    let potential-winners []
    foreach (range length players-list) [ i ->
      if (item i total-scores) = max-score [
        set potential-winners lput (item i players-list) potential-winners
      ]
    ]

    ; Reset final winner status for all players before assigning
    ask players [ set winner? false ]

    ; Determine final winner
    if length potential-winners = 1 [
      let winner-agent first potential-winners
      ask winner-agent [
        set winner? true
        set win-count win-count + 1
      ]
      output-print (sentence "Winner: Player" [player-id] of winner-agent
                    "with score" precision max-score 1
                    "and experience" precision [experience] of winner-agent 1)
    ]

    if length potential-winners > 1 [
      ; Tie-breaking: first use experience among the tied players
      let max-exp max map [p -> [experience] of p] potential-winners
      let exp-tied-winners filter [p -> [experience] of p = max-exp] potential-winners

      if length exp-tied-winners = 1 [
        ask first exp-tied-winners [
          set winner? true
          set win-count win-count + 1
        ]
        output-print (sentence "Tie broken by experience. Winner: Player"
                      [player-id] of first exp-tied-winners)
      ]
      if length exp-tied-winners > 1 [
        ; If still tied on experience, use lowest bid as final tie-breaker
        let min-bid min map [p -> [my-bid] of p] exp-tied-winners
        let final-winner one-of filter [p -> [my-bid] of p = min-bid] exp-tied-winners
        ask final-winner [
          set winner? true
          set win-count win-count + 1
        ]
        output-print (sentence "Tie broken by experience and lowest bid. Winner: Player"
                      [player-id] of final-winner "with bid" precision [my-bid] of final-winner 2)
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STRATEGY UPDATE PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-strategies
  ; Update bidding histories
  ask players [
    set history-bids fput my-bid history-bids
    ; Cap history to prevent memory issues on long runs
    if length history-bids > 50 [
      set history-bids but-last history-bids
    ]

    ; Update experience based on outcome
    ifelse winner? = true [
      set experience experience + winner-exp
      update-winner-strategy
    ] [
      set experience experience + loser-exp
      update-loser-strategy
    ]

    ; Calculate risk attitude *after* updating experience to use the latest value.
    calculate-risk-attitude

    ; Calculate bid adjustment based on historical performance
    calculate-bid-adjustment

    update-market-position
  ]

  ; Efficiently get winner bid once, then update all players' intelligence
  let winner-bid -1 ; Default to -1 if no winner
  if any? players with [winner?] [
    set winner-bid [my-bid] of one-of players with [winner?]
  ]
  update-profit-learning winner-bid

  ; Update global winning bids list
  if winner-bid != -1 [
    set winning-bids-list fput winner-bid winning-bids-list
    ; Cap the list to prevent memory issues on long runs
    if length winning-bids-list > 500 [
      set winning-bids-list but-last winning-bids-list
    ]
  ]
end

to update-winner-strategy
  ; Winners become slightly more conservative to maintain competitive edge
  set bid-strategy bid-strategy * 0.995  ; slight reduction in base strategy
  if bid-strategy < 20 [ set bid-strategy 20 ]  ; enforce minimum bid strategy

  ; Update profitability estimate (simplified)
  let tender-value [value] of one-of tenders with [id = id-active-tender]
  set profitability ((tender-value - my-bid) / tender-value) * 100
end

to update-loser-strategy
  ; Losers adjust strategy more aggressively
  if total-bids > 1 [
    let current-performance win-count / total-bids
    if current-performance < 0.2 [  ; if winning less than 20%
      set bid-strategy bid-strategy * 0.99  ; more aggressive bidding
    ]
  ]
end

to calculate-bid-adjustment
  ; Enhanced bid adjustment calculation
  if length winning-bids-list > 0 and length history-bids > 0 [
    let adjustment-sum 0
    let comparison-rounds min (list length winning-bids-list length history-bids)

    foreach range comparison-rounds [
      i ->
      let winning-bid item i winning-bids-list
      let my-historical-bid item i history-bids
      if winning-bid > 0 [
        set adjustment-sum adjustment-sum + (my-historical-bid / winning-bid)
      ]
    ]

    if comparison-rounds > 0 [
      let average-ratio adjustment-sum / comparison-rounds
      set bid-adjustment (1 - average-ratio) * 0.5  ; damped adjustment

      ; Bounds checking
      if bid-adjustment > 0.2 [ set bid-adjustment 0.2 ]
      if bid-adjustment < -0.2 [ set bid-adjustment -0.2 ]
    ]
  ]
end

to update-market-position
  ; Calculate relative market position (0 = worst, 1 = best)
  let my-win-rate 0
  if total-bids > 0 [ set my-win-rate win-count / total-bids ]

  let total-wins sum [win-count] of players
  let total-bids-all sum [total-bids] of players
  if total-bids-all > 0 [
    let avg-win-rate total-wins / total-bids-all
    set market-position my-win-rate / avg-win-rate
    if market-position > 2 [ set market-position 2 ]  ; cap at 2x average
  ]
end

to calculate-risk-attitude
  ; Risk attitude based on experience levels with smoother transitions
  if experience <= EXPERIENCE-THRESHOLD-LOW [
    set risk-attitude propension  ; young firms are more aggressive (higher bids)
  ]

  if experience > EXPERIENCE-THRESHOLD-LOW and experience <= EXPERIENCE-THRESHOLD-HIGH [
    set risk-attitude risk-aversion-medium-exp  ; moderate experience, moderate aversion
  ]

  if experience > EXPERIENCE-THRESHOLD-HIGH [
    set risk-attitude risk-aversion-high-exp  ; experienced firms are more conservative
  ]
end

to calculate-current-quality [complexity]
  ; Quality offered varies based on:
  ; 1. Base quality capability
  ; 2. Tender complexity requirements with player-specific penalty
  ; 3. Random variation representing effort/focus

  let quality-effort random-float 1.0  ; 0.0 to 1.0 effort level
  ; Player-specific complexity penalty: lower base quality players are more penalized by complexity
  let quality-capability-factor base-quality / MAX-QUALITY  ; 0.5 to 1.0 based on base quality relative to max
  let complexity-penalty (1 - quality-capability-factor) * complexity * 0.3  ; Penalty scales with complexity and inversely with quality capability
  let complexity-adjustment (complexity * 0.2) - complexity-penalty  ; Base adjustment reduced by penalty for lower quality players

  set current-quality base-quality + (quality-effort * quality-base) + complexity-adjustment

  ; Ensure quality stays within bounds
  if current-quality < MIN-QUALITY [ set current-quality MIN-QUALITY ]
  if current-quality > MAX-QUALITY [ set current-quality MAX-QUALITY ]

  ; Track quality history
  set history-qualities fput current-quality history-qualities
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PROFIT MARGIN LEARNING AND ADAPTATION
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-profit-learning [winner-bid]
  ; Players learn and adapt their profit targeting based on outcomes
  ask players [
    ; Calculate actual profit margin if won
    if winner? and total-bids > 0 [
      let actual-profit calculate-actual-profit-margin
      set profit-history lput actual-profit profit-history

      ; Keep only recent profit history
      if length profit-history > 10 [
        set profit-history but-first profit-history
      ]

      ; Adjust target profit margin based on learning curve
      adapt-profit-targets
    ]

    ; Update cost estimation accuracy based on experience
    improve-cost-estimation

    ; Update market intelligence with winner information
    if winner-bid != -1 [
      let winner-data item 2 market-intelligence
      set winner-data lput winner-bid winner-data
      if length winner-data > 10 [
        set winner-data but-first winner-data
      ]
      set market-intelligence replace-item 2 market-intelligence winner-data
    ]

    ; Update own bid history in market intelligence
    let own-bid-data item 0 market-intelligence
    set own-bid-data lput my-bid own-bid-data
    if length own-bid-data > 10 [
      set own-bid-data but-first own-bid-data
    ]
    set market-intelligence replace-item 0 market-intelligence own-bid-data
  ]
end

to-report calculate-actual-profit-margin
  ; Calculate actual profit margin achieved
  let current-tender one-of tenders with [id = id-active-tender]
  let actual-cost [estimated-cost] of current-tender

  if my-bid > actual-cost [
    report (my-bid - actual-cost) / my-bid
  ]
  report 0
end

to adapt-profit-targets
  ; Adapt profit targets based on learning curve and recent performance
  if length profit-history > 2 [
    let recent-avg-profit mean profit-history
    let target-gap recent-avg-profit - target-profit-margin

    ; Adjust target based on learning curve speed and direction
    let adjustment target-gap * margin-adjustment-rate * learning-curve-speed

    ; Apply archetype-specific learning patterns
    if bidding-archetype = "adaptive" [
      set adjustment adjustment * 1.5  ; adaptive players learn faster
    ]
    if bidding-archetype = "conservative" [
      set adjustment adjustment * 0.5  ; conservative players change slowly
    ]

    set target-profit-margin target-profit-margin + adjustment

    ; Ensure target stays within reasonable bounds
    if target-profit-margin < MIN-PROFIT-MARGIN [ set target-profit-margin MIN-PROFIT-MARGIN ]
    if target-profit-margin > MAX-PROFIT-MARGIN [ set target-profit-margin MAX-PROFIT-MARGIN ]
  ]
end

to improve-cost-estimation
  ; Gradually improve cost estimation accuracy through experience
  let improvement-rate learning-curve-speed * 0.01  ; 1% per round maximum
  set cost-estimation-accuracy cost-estimation-accuracy + improvement-rate

  ; Cap at maximum accuracy
  if cost-estimation-accuracy > 0.95 [ set cost-estimation-accuracy 0.95 ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DATA COLLECTION AND ANALYSIS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to collect-round-data
  ; Collect enhanced statistics for each round
  let current-bids [my-bid] of players
  let current-qualities [current-quality] of players
  let current-winner-exp [experience] of one-of players with [winner? = true]

  let avg-bid mean current-bids
  let min-bid min current-bids
  let max-bid max current-bids
  let bid-spread max-bid - min-bid
  let avg-quality mean current-qualities

  ; Calculate market concentration (simplified HHI)
  let current-market-shares []
  ask players [
    let share 0
    if total-bids > 0 [ set share win-count / total-bids ]
    set current-market-shares lput share current-market-shares
  ]
  let hhi sum map [s -> s * s] current-market-shares

  ; Store round statistics
  let round-data (list
    ticks avg-bid min-bid max-bid bid-spread
    avg-quality current-winner-exp hhi
  )
  set round-statistics lput round-data round-statistics
  ; Cap the list to prevent memory issues on long runs
  if length round-statistics > 500 [
    set round-statistics but-last round-statistics
  ]

  ; Also append to market-statistics for full round-by-round data
  set market-statistics lput round-data market-statistics
  if length market-statistics > 500 [
    set market-statistics but-last market-statistics
  ]
end

to finalize-statistics
  ; Output final summary statistics
  output-print "=================="
  output-print "SIMULATION SUMMARY"
  output-print "=================="

  ask players [
    let win-rate 0
    if total-bids > 0 [ set win-rate precision (win-count / total-bids * 100) 1 ]
    output-print (sentence "Player" who ": " win-count "wins /" total-bids "bids (" win-rate "%)")
  ]

  if length round-statistics > 0 [
    let final-avg-bid mean map [r -> item 1 r] round-statistics
    let final-avg-quality mean map [r -> item 5 r] round-statistics
    output-print (sentence "Average bid across all rounds:" precision final-avg-bid 2)
    output-print (sentence "Average quality across all rounds:" precision final-avg-quality 2)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ENHANCED REPORTING FUNCTIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report bids-bs
  report [my-bid] of players
end

to-report win-bid
  report [my-bid] of players with [winner? = true]
end

to-report bid-adj
  report [bid-adjustment * 100] of players
end

to-report quality-offered
  report [current-quality] of players
end

to-report base-quality-levels
  report [base-quality] of players
end

to-report experience-levels
  report [experience] of players
end

to-report win-rates
  report [ifelse-value (total-bids > 0) [win-count / total-bids * 100] [0]] of players
end

to-report market-positions
  report [market-position] of players
end

to-report tender-values
  if any? tenders [ report [value] of tenders ]
  report []
end

to-report tender-types
  if any? tenders [ report [tender-type] of tenders ]
  report []
end

to-report average-bid-per-round
  if length round-statistics > 0 [
    report map [r -> item 1 r] round-statistics
  ]
  report []
end

to-report bid-spread-per-round
  if length round-statistics > 0 [
    report map [r -> item 4 r] round-statistics
  ]
  report []
end

to-report bidding-archetypes
  report [bidding-archetype] of players
end

to-report strategy-confidence-levels
  report [strategy-confidence] of players
end

to-report social-influence-levels
  report [social-influence] of players
end

to-report market-knowledge-levels
  report [market-knowledge] of players
end

to-report performance-trends
  report [performance-trend] of players
end

to-report market-shares
  report [market-share] of players
end

to-report learning-network-size
  report [length learning-partners] of players
end

to-report archetype-distribution
  let archetypes bidding-archetypes
  let aggressive length filter [a -> a = "aggressive"] archetypes
  let conservative length filter [a -> a = "conservative"] archetypes
  let adaptive length filter [a -> a = "adaptive"] archetypes
  let follower length filter [a -> a = "follower"] archetypes
  report (list aggressive conservative adaptive follower)
end

to-report meat-weights
  report (list meat-price-weight meat-quality-weight meat-experience-weight)
end

to-report social-learning-stats
  report (list social-learning-rate market-intelligence-level strategy-imitation-threshold)
end

to-report average-strategy-confidence
  report mean [strategy-confidence] of players
end

to-report market-concentration-hhi
  let shares [market-share] of players
  report sum map [s -> s * s] shares
end

to-report experience-performance-data
  ; Returns list of [experience win-rate] pairs for correlation analysis
  let data []
  ask players [
    let win-rate ifelse-value (total-bids > 0) [win-count / total-bids] [0]
    set data lput (list experience win-rate) data
  ]
  report data
end

to-report experience-performance-correlation
  ; Calculate correlation coefficient between experience and performance
  let data experience-performance-data
  if length data < 2 [ report 0 ]

  ; The stats extension requires a table to calculate the correlation matrix.
  let tbl stats:newtable-from-row-list data
  let corr-matrix stats:correlation tbl

  ; In a 2x2 correlation matrix, the off-diagonal element is the Pearson coefficient.
  ; We can take the element at row 0, column 1. We add checks to prevent runtime errors.
  if is-list? corr-matrix and length corr-matrix >= 2 [
    let first-row item 0 corr-matrix
    if is-list? first-row and length first-row >= 2 [
      report item 1 first-row
    ]
  ]

  report 0 ; Return 0 if something went wrong or correlation is not possible.
end

to-report average-experience-by-performance-tier
  ; Returns average experience for high, medium, and low performers
  let performers experience-performance-data
  if length performers = 0 [ report [0 0 0] ]

  ; Sort by performance (win rate)
  let sorted-performers sort-by [[d1 d2] -> (item 1 d1) > (item 1 d2)] performers
  let num-players length sorted-performers

  ; Divide into tiers
  let high-tier-size max (list 1 (floor (num-players / 3)))
  let low-tier-size max (list 1 (floor (num-players / 3)))

  let high-performers sublist sorted-performers 0 high-tier-size
  let low-performers sublist sorted-performers (num-players - low-tier-size) num-players
  let mid-performers sublist sorted-performers high-tier-size (num-players - low-tier-size)

  let high-avg-exp ifelse-value (length high-performers > 0) [mean map [d -> item 0 d] high-performers] [0]
  let mid-avg-exp ifelse-value (length mid-performers > 0) [mean map [d -> item 0 d] mid-performers] [0]
  let low-avg-exp ifelse-value (length low-performers > 0) [mean map [d -> item 0 d] low-performers] [0]

  report (list high-avg-exp mid-avg-exp low-avg-exp)
end

;; Economic modeling and profit targeting reporters
to-report target-profit-margins
  report [target-profit-margin * 100] of players  ; return as percentages
end

to-report current-profit-margins
  report [current-profit-margin * 100] of players  ; return as percentages
end

to-report cost-estimation-accuracies
  report [cost-estimation-accuracy * 100] of players  ; return as percentages
end

to-report learning-curve-speeds
  report [learning-curve-speed] of players
end

to-report risk-premiums
  report [risk-premium * 100] of players  ; return as percentages
end

to-report margin-sensitivity-levels
  report [margin-sensitivity] of players
end

to-report average-target-profit-margin
  report precision (mean [target-profit-margin] of players * 100) 1
end

to-report average-achieved-profit-margin
  let achieved-margins [current-profit-margin] of players with [current-profit-margin > 0]
  if length achieved-margins > 0 [
    report precision (mean achieved-margins * 100) 1
  ]
  report 0
end

to-report average-cost-estimation-accuracy
  report precision (mean [cost-estimation-accuracy] of players * 100) 1
end

to-report average-learning-speed
  report precision (mean [learning-curve-speed] of players) 2
end

to-report profit-margin-variance
  let margins [target-profit-margin] of players
  if length margins > 1 [
    report precision (variance margins * 100 * 100) 1  ; convert to percentage variance
  ]
  report 0
end

to-report archetype-profit-performance
  ; Returns profit performance by archetype
  let aggressive-margins []
  let conservative-margins []
  let adaptive-margins []
  let follower-margins []

  ask players [
    if current-profit-margin > 0 [
      if bidding-archetype = "aggressive" [
        set aggressive-margins lput current-profit-margin aggressive-margins
      ]
      if bidding-archetype = "conservative" [
        set conservative-margins lput current-profit-margin conservative-margins
      ]
      if bidding-archetype = "adaptive" [
        set adaptive-margins lput current-profit-margin adaptive-margins
      ]
      if bidding-archetype = "follower" [
        set follower-margins lput current-profit-margin follower-margins
      ]
    ]
  ]

  let agg-avg ifelse-value (length aggressive-margins > 0) [mean aggressive-margins * 100] [0]
  let con-avg ifelse-value (length conservative-margins > 0) [mean conservative-margins * 100] [0]
  let ada-avg ifelse-value (length adaptive-margins > 0) [mean adaptive-margins * 100] [0]
  let fol-avg ifelse-value (length follower-margins > 0) [mean follower-margins * 100] [0]

  report (list precision agg-avg 1 precision con-avg 1 precision ada-avg 1 precision fol-avg 1)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PLOTTING PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to refresh-plots
  ; Update all plots with current round data
  update-bid-trends-plot
  update-bid-spread-plot
  update-archetype-win-rates-plot
  update-strategy-confidence-plot
  update-experience-performance-plot
  update-profit-margins-plot
end

to update-bid-trends-plot
  ; Plot average, min, and max bids over time
  if any? players with [my-bid > 0] [
    let current-bids [my-bid] of players with [my-bid > 0]
    let current-ideal-bids [ideal-bid] of players with [ideal-bid > 0]

    set-current-plot "Bid Trends (Ideal vs Actual)"

    set-current-plot-pen "avg-ideal-bid"
    if any? players with [ideal-bid > 0] [
      plot precision mean current-ideal-bids 3
    ]

    set-current-plot-pen "avg-bid"
    plot precision mean current-bids 3

    set-current-plot-pen "min-bid"
    plot precision min current-bids 3

    set-current-plot-pen "max-bid"
    plot precision max current-bids 3
  ]
end

to update-bid-spread-plot
  ; Plot bid spread (max - min bid) over time
  if any? players with [my-bid > 0] [
    let current-bids [my-bid] of players with [my-bid > 0]
    let spread max current-bids - min current-bids

    set-current-plot "Bid Spread Over Time"
    set-current-plot-pen "spread"
    plot precision spread 3
  ]
end

to update-archetype-win-rates-plot
  ; Plot share of total wins for each bidding archetype
  set-current-plot "Win Rates by Archetype"

  ; Calculate total wins so far across all players
  let total-wins-so-far sum [win-count] of players
  if total-wins-so-far = 0 [ stop ] ; Stop if no wins have occurred yet

  ; Get player sets for each archetype
  let aggressive-players players with [bidding-archetype = "aggressive"]
  let conservative-players players with [bidding-archetype = "conservative"]
  let adaptive-players players with [bidding-archetype = "adaptive"]
  let follower-players players with [bidding-archetype = "follower"]

  ; --- Plot share of wins for each archetype ---

  set-current-plot-pen "aggressive"
  let aggressive-wins sum [win-count] of aggressive-players
  plot precision (aggressive-wins / total-wins-so-far * 100) 3

  set-current-plot-pen "conservative"
  let conservative-wins sum [win-count] of conservative-players
  plot precision (conservative-wins / total-wins-so-far * 100) 3

  set-current-plot-pen "adaptive"
  let adaptive-wins sum [win-count] of adaptive-players
  plot precision (adaptive-wins / total-wins-so-far * 100) 3

  set-current-plot-pen "follower"
  let follower-wins sum [win-count] of follower-players
  plot precision (follower-wins / total-wins-so-far * 100) 3
end

to update-strategy-confidence-plot
  ; Plot average strategy confidence over time
  set-current-plot "Average Strategy Confidence"
  set-current-plot-pen "confidence"
  plot precision average-strategy-confidence 3
end

to update-experience-performance-plot
  ; Plot experience vs performance analysis
  set-current-plot "Experience vs Performance"

  ; Plot correlation coefficient over time
  set-current-plot-pen "correlation"
  let correlation experience-performance-correlation
  plot precision correlation 3

  ; Plot average experience by performance tier
  let tier-data average-experience-by-performance-tier

  set-current-plot-pen "high-performers"
  plot precision (item 0 tier-data) 3

  set-current-plot-pen "mid-performers"
  plot precision (item 1 tier-data) 3

  set-current-plot-pen "low-performers"
  plot precision (item 2 tier-data) 3

  ; Plot average experience vs average performance
  set-current-plot-pen "avg-experience"
  let avg-exp mean [experience] of players
  plot precision (avg-exp / 10) 3  ; normalize to 0-1 scale for better visualization
end

to update-profit-margins-plot
  ; Plot average target profit margins for each archetype over time
  set-current-plot "Profit Margins by Archetype"

  ; Calculate average target margins for each archetype
  let aggressive-players players with [bidding-archetype = "aggressive"]
  let conservative-players players with [bidding-archetype = "conservative"]
  let adaptive-players players with [bidding-archetype = "adaptive"]
  let follower-players players with [bidding-archetype = "follower"]

  ; Plot aggressive target margins
  set-current-plot-pen "aggressive"
  if any? aggressive-players [
    let avg-margin mean [target-profit-margin * 100] of aggressive-players
    plot precision avg-margin 1
  ]

  ; Plot conservative target margins
  set-current-plot-pen "conservative"
  if any? conservative-players [
    let avg-margin mean [target-profit-margin * 100] of conservative-players
    plot precision avg-margin 1
  ]

  ; Plot adaptive target margins
  set-current-plot-pen "adaptive"
  if any? adaptive-players [
    let avg-margin mean [target-profit-margin * 100] of adaptive-players
    plot precision avg-margin 1
  ]

  ; Plot follower target margins
  set-current-plot-pen "follower"
  if any? follower-players [
    let avg-margin mean [target-profit-margin * 100] of follower-players
    plot precision avg-margin 1
  ]
end

to initialize-plots
  ; Initialize all plots
  clear-all-plots

  ; Setup Average Bid Trends plot
  set-current-plot "Bid Trends (Ideal vs Actual)"
  set-plot-x-range 0 number-rounds

  ; Setup Bid Spread plot
  set-current-plot "Bid Spread Over Time"
  set-plot-x-range 0 number-rounds

  ; Setup Archetype Win Rates plot
  set-current-plot "Win Rates by Archetype"
  set-plot-x-range 0 number-rounds
  set-plot-y-range 0 100

  ; Setup Strategy Confidence plot
  set-current-plot "Average Strategy Confidence"
  set-plot-x-range 0 number-rounds
  set-plot-y-range 0 1

  ; Setup Profit Margins by Archetype plot
  set-current-plot "Profit Margins by Archetype"
  set-plot-x-range 0 number-rounds
  set-plot-y-range 0 50  ; profit margins range from 0% to 50%

  ; Setup Experience vs Performance plot
  set-current-plot "Experience vs Performance"
  set-plot-x-range 0 number-rounds
  set-plot-y-range -1 1   ; correlation (Pearson r) ranges from -1 to 1
end
@#$#@#$#@
GRAPHICS-WINDOW
204
10
771
578
-1
-1
16.94
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
12
85
184
118
number-players
number-players
2
50
10.0
1
1
NIL
HORIZONTAL

BUTTON
26
10
89
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
10
159
43
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
121
183
154
number-rounds
number-rounds
1
100
100.0
1
1
NIL
HORIZONTAL

OUTPUT
2227
17
2910
677
11

BUTTON
27
46
158
79
NIL
simulate-n-rounds
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
11
156
183
189
quality-base
quality-base
1
6
4.0
1
1
NIL
HORIZONTAL

SLIDER
11
192
183
225
propension
propension
0.05
0.1
0.07
0.01
1
NIL
HORIZONTAL

SLIDER
11
228
183
261
risk-aversion-medium-exp
risk-aversion-medium-exp
0.025
0.05
0.04
0.005
1
NIL
HORIZONTAL

SLIDER
10
264
182
297
risk-aversion-high-exp
risk-aversion-high-exp
0.05
0.1
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
10
299
182
332
winner-exp
winner-exp
0.25
0.50
0.4
0.05
1
NIL
HORIZONTAL

SLIDER
10
334
182
367
loser-exp
loser-exp
0.50
1
0.5
0.05
1
NIL
HORIZONTAL

MONITOR
809
35
903
80
Current Round
ticks
3
1
11

MONITOR
902
35
1038
80
Current Tender Value
first tender-values
3
1
11

MONITOR
1039
35
1170
80
Current Tender Type
first tender-types
3
1
11

TEXTBOX
932
17
1082
35
Current Status
15
0.0
1

TEXTBOX
924
85
1074
103
Market Dynamics
15
0.0
1

MONITOR
804
105
927
150
Avg Bid This Round
precision (mean bids-bs) 3
3
1
11

MONITOR
930
105
1063
150
Market Concentration
precision market-concentration-hhi 3
3
1
11

MONITOR
1064
105
1183
150
Number of Players
count players
3
1
11

TEXTBOX
912
159
1070
195
Quality & Experience
15
0.0
1

MONITOR
805
182
927
227
Avg Quality Offered
precision (mean quality-offered) 3
13
1
11

MONITOR
929
182
1059
227
Avg Experience Level
precision (mean experience-levels) 3
3
1
11

MONITOR
1062
182
1170
227
Avg Base Quality
precision (mean base-quality-levels) 3
3
1
11

TEXTBOX
922
235
1072
253
Social Features
15
0.0
1

MONITOR
804
255
955
300
Avg Strategy Confidence
precision average-strategy-confidence 3
3
1
11

MONITOR
959
255
1085
300
Avg Social Influence
precision (mean social-influence-levels) 3
3
1
11

MONITOR
1085
255
1224
300
Avg Market Knowledge
precision (mean market-knowledge-levels) 3
3
1
11

TEXTBOX
907
305
1072
341
Archetype Distribution
15
0.0
1

MONITOR
804
325
926
370
Aggressive Players
item 0 archetype-distribution
3
1
11

MONITOR
929
325
1061
370
Conservative Players
item 1 archetype-distribution
3
1
11

MONITOR
1062
325
1170
370
Adaptive Players
item 2 archetype-distribution
3
1
11

MONITOR
1169
325
1273
370
Follower Players
item 3 archetype-distribution
3
1
11

TEXTBOX
929
375
1079
393
MEAT Criteria
15
0.0
1

MONITOR
804
395
888
440
Price Weight
item 0 meat-weights
3
1
11

MONITOR
890
395
981
440
Quality Weight
item 1 meat-weights
3
1
11

MONITOR
982
395
1097
440
Experience Weight
item 2 meat-weights
3
1
11

PLOT
1299
17
1753
236
Bid Trends (Ideal vs Actual)
Round
Average Bid
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"avg-bid" 1.0 0 -2674135 true "" ""
"min-bid" 1.0 0 -13345367 true "" ""
"max-bid" 1.0 0 -13840069 true "" ""
"avg-ideal-bid" 1.0 0 -955883 true "" ""

PLOT
1754
17
2209
236
Bid Spread Over Time
Round
Bid Spread
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"spread" 1.0 0 -955883 true "" ""

PLOT
1299
235
1753
452
Win Rates by Archetype
Round
Share of Wins (%)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"aggressive" 1.0 0 -2674135 true "" ""
"conservative" 1.0 0 -13345367 true "" ""
"adaptive" 1.0 0 -955883 true "" ""
"follower" 1.0 0 -1184463 true "" ""

PLOT
1754
235
2209
450
Profit Margins by Archetype
Round
Margin (%)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"aggressive" 1.0 0 -2674135 true "" ""
"conservative" 1.0 0 -13345367 true "" ""
"adaptive" 1.0 0 -955883 true "" ""
"follower" 1.0 0 -1184463 true "" ""

PLOT
1299
452
1753
676
Average Strategy Confidence
Round
Confidence Level
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"confidence" 1.0 0 -11221820 true "" ""

SLIDER
9
403
183
436
meat-price-weight
meat-price-weight
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
9
439
184
472
meat-quality-weight
meat-quality-weight
0
1
0.4
0.1
1
NIL
HORIZONTAL

SLIDER
9
475
184
508
meat-experience-weight
meat-experience-weight
0
1
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
9
523
185
556
social-learning-rate
social-learning-rate
0
0.5
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
9
557
186
590
strategy-imitation-threshold
strategy-imitation-threshold
0
1
0.5
0.05
1
NIL
HORIZONTAL

SLIDER
9
592
187
625
market-intelligence-level
market-intelligence-level
0
1
0.5
0.05
1
NIL
HORIZONTAL

PLOT
1755
450
2209
675
Experience vs Performance
Round
Exp / Corr
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"correlation" 1.0 0 -13345367 true "" ""
"high-performers" 1.0 0 -2674135 true "" ""
"mid-performers" 1.0 0 -13840069 true "" ""
"low-performers" 1.0 0 -1184463 true "" ""
"avg-experience" 1.0 0 -955883 true "" ""

TEXTBOX
39
372
166
400
Sum of the MEAT weights should be 1
11
0.0
1

@#$#@#$#@
## WHAT IS IT?

This is an Agent-Based Model (ABM) that simulates a competitive public tender process. It is designed to explore how complex bidding behaviors and market dynamics, such as a "race to the bottom," emerge from the interactions of individual firms (agents) with different strategies and capabilities.

## HOW IT WORKS

The simulation consists of a series of tender rounds where player agents compete for contracts.

**Player Agents:**
Each agent represents a firm with a unique set of attributes:
-   **Archetype:** Players are assigned an archetype ("aggressive," "conservative," "adaptive," or "follower") that governs their bidding behavior and risk tolerance.
-   **Experience & Quality:** Players have an experience level and a base quality capability, which influence their performance and how they are evaluated.
-   **Profit Targeting:** Each player has an internal target profit margin they aim to achieve.

**Bidding Process:**
1.  **Ideal Bid:** A player first calculates an "ideal bid" based on their estimated cost for the tender and their target profit margin.
2.  **Strategic Adjustments:** This ideal bid is then heavily adjusted based on a `bid-strategy` value, which is learned over time. Players adapt this strategy by observing the market and the success of others.
3.  **Final Bid:** The final bid is a result of these adjustments, reflecting a balance between the player's ideal profit and the competitive reality of the market.

**Evaluation & Learning:**
-   **MEAT Criteria:** Tenders are awarded using the Most Economically Advantageous Tender (MEAT) criteria, which is a weighted combination of **price**, **quality**, and **experience**. You can adjust the weights of these criteria using the sliders.
-   **Social Learning:** Players learn from their peers. They observe the performance of others—not just who wins, but who wins *profitably*—and may imitate the strategies of the most successful players. This drives the evolution of strategies in the market.

## HOW TO USE IT

**Buttons:**
-   **setup:** Resets the simulation and creates the players and evaluators.
-   **go:** Runs the simulation one round at a time.
-   **simulate-n-rounds:** Runs the simulation for the number of rounds specified by the `number-rounds` slider.

**Key Sliders:**
-   **number-players:** Sets the number of competing firms.
-   **number-rounds:** Sets the duration of the simulation.
-   **meat-price-weight, meat-quality-weight, meat-experience-weight:** Adjust the importance of each factor in the tender evaluation. The model will automatically normalize these so they sum to 1.
-   **social-learning-rate / strategy-imitation-threshold:** Control how quickly and easily players imitate each other's strategies.

**Key Plots:**
-   **Bid Trends (Ideal vs Actual):** This plot is key to observing emergent behavior. It shows the average "ideal bid" (what players *want* to bid for profit) versus the average "actual bid" (what they bid after competitive adjustments). The divergence between these lines reveals the pressure of the market.
-   **Win Rates by Archetype:** Shows the relative market share (percentage of total wins) held by each player archetype over time.
-   **Profit Margins by Archetype:** Tracks the average profit margin achieved by each archetype.

## THINGS TO TRY

-   **The Race to the Bottom:** Run a simulation for 100 rounds. Watch the "Bid Trends (Ideal vs Actual)" plot. Does a gap form between the ideal and actual bids? This shows the competitive pressure forcing players to abandon their profit targets.
-   **Varying MEAT Criteria:** Set the `meat-price-weight` to be very high (e.g., 0.8) and run the simulation. Which archetype tends to dominate? Now try again with `meat-quality-weight` set high.
-   **Market Competition:** Run a simulation with a low `number-players` (e.g., 5) and another with a high number (e.g., 40). How does the level of competition affect the "race to the bottom"?
-   **Social Dynamics:** Turn the `strategy-imitation-threshold` down to make imitation very easy. Does one strategy quickly take over the entire market?

## EXTENDING THE MODEL

-   **Market Shocks:** Introduce sudden changes to the simulation, such as a sudden increase in the `BASE-TENDER-VALUE` or a change in the MEAT weights mid-run.
-   **Player-Specific Knowledge:** Give players imperfect information. For example, some players might have better `cost-estimation-accuracy` than others.
-   **Coalitions:** Allow players to form temporary alliances to bid on larger, more complex tenders.

## CREDITS AND REFERENCES
Made by Riccardo Pizzuti  
Mail: r.pizzuti92@gmail.com
Linkedin: https://www.linkedin.com/in/ricpiz92/
GitHub: https://github.com/RicPiz
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
