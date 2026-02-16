import time
import subprocess
import statistics

def run_bench(cmd, iterations=20):
    times = []
    for _ in range(iterations):
        start = time.perf_counter()
        subprocess.run(cmd, shell=True, capture_output=True)
        end = time.perf_counter()
        times.append(end - start)
    return times

print("Benchmarking ShellCheck execution...")

docker_cmd = "docker exec mcp-server-container shellcheck --version"
local_cmd = "shellcheck --version"

print(f"\nRunning Local benchmark ({local_cmd})...")
local_times = run_bench(local_cmd)

print(f"Running Docker benchmark ({docker_cmd})...")
docker_times = run_bench(docker_cmd)

local_avg = statistics.mean(local_times)
docker_avg = statistics.mean(docker_times)
overhead = docker_avg - local_avg

print("\n--- RESULTS ---")
print(f"Local Average:  {local_avg:.4f}s")
print(f"Docker Average: {docker_avg:.4f}s")
print(f"Overhead:       {overhead:.4f}s")
print(f"Docker is {docker_avg/local_avg:.1f}x slower for this simple command.")

print("\n--- STATS ---")
print(f"Local Min/Max:  {min(local_times):.4f}s / {max(local_times):.4f}s")
print(f"Docker Min/Max: {min(docker_times):.4f}s / {max(docker_times):.4f}s")
