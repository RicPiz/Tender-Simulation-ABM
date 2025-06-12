# Tender-Simulation-ABM

> An Agent-Based Model in NetLogo that simulates a competitive public tender process and explores the emergent market dynamics of bidding behavior.

This model was created to explore how complex behaviors, such as a "race to the bottom" in bidding, can emerge from the interactions of individual agents with different strategies, capabilities, and learning mechanisms.

---

## Key Features

*   **Behavioral Archetypes:** Agents are assigned one of four distinct archetypes ("aggressive," "conservative," "adaptive," or "follower") that governs their bidding strategy and risk tolerance.
*   **Profit vs. Winning:** The model captures the fundamental tension between an agent's desire to win a tender and its need to maintain a profitable margin.
*   **Social Learning:** Agents learn by observing their peers. They don't just copy winners; they evaluate the *profitability* of winning strategies, leading to a complex, evolving market.
*   **MEAT Evaluation:** Tenders are awarded based on the "Most Economically Advantageous Tender" (MEAT) criteria, a configurable weighted average of **price, quality, and experience**.
*   **Emergent Behavior Visualization:** The model includes custom plots specifically designed to visualize the emergent "race to the bottom," showing the divergence between the profitable "ideal bids" and the competitive "actual bids" over time.

## Screenshot

![NetLogo Simulation Interface](interface.png)

## How to Run the Model

1.  You will need to have [**NetLogo (version 6.4.0 or newer)**](https://ccl.northwestern.edu/netlogo/) installed.
2.  Download the `tender-simulation-abm.nlogo` file from this repository.
3.  Open the file in NetLogo.
4.  Press the **`setup`** button to initialize the simulation.
5.  Press the **`go`** button to run the simulation one round at a time, or use the **`simulate-n-rounds`** button to run it for a specific number of rounds.

## Understanding the Simulation: The "Race to the Bottom"

The most interesting emergent behavior in this model is the "race to the bottom." You can observe this phenomenon using the **"Bid Trends (Ideal vs Actual)"** plot.

*   **Ideal Bid (Blue Line):** This is the bid an agent *wants* to make to meet its internal target profit margin. It's calculated rationally based on estimated costs and desired profit.
*   **Actual Bid (Red Line):** This is the bid the agent *actually* submits after applying its learned competitive strategies and risk adjustments.

In many simulation runs, you will see a significant gap form between these two lines. This divergence shows the immense competitive pressure of the market forcing agents to abandon their profitable strategies in favor of extremely low bids just to have a chance at winning.

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.

## Credits

*   **Author:** Riccardo Pizzuti
*   **Mail:** r.pizzuti92@gmail.com
*   **LinkedIn:** [https://www.linkedin.com/in/ricpiz92/](ricpiz92)
*   **GitHub:** [https://github.com/RicPiz](RicPiz)
