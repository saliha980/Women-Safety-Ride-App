import matplotlib.pyplot as plt

# MEC server names
servers = ["MBS MEC", "SBS MEC", "Relay MEC", "D2D Node"]

# Different CPU utilization values (75% to 95%)
cpu_utilization = [82, 91, 76, 88]

# Create figure
plt.figure(figsize=(9, 4.2))

# Create bars
bars = plt.bar(
    servers,
    cpu_utilization,
    width=0.35,
    color="#C96868",
    edgecolor="#555555",
    linewidth=0.8
)

# Title
plt.title(
    "MEC Server Computational Share Utilization",
    fontsize=12,
    fontweight="bold"
)

# Y-axis label
plt.ylabel("Allocated CPU Share (%)")

# Set Y-axis from 0 to 100
plt.ylim(0, 100)

# Y-axis ticks
plt.yticks(range(0, 101, 10))

# Grid
plt.grid(
    axis="y",
    linestyle="-",
    alpha=0.25
)

# Add value on top of each bar
for bar, value in zip(bars, cpu_utilization):
    plt.text(
        bar.get_x() + bar.get_width() / 2,
        value + 1,
        f"{value}%",
        ha="center",
        va="bottom",
        fontsize=10
    )

# Adjust layout
plt.tight_layout()

# Show graph
plt.show()