#!/bin/bash

LOG_FILE="access.log"
OUTPUT="analysis_results.txt"

# Reset output file
> "$OUTPUT"

# 1. Count total requests
total_requests=$(wc -l < "$LOG_FILE")
echo "Total Requests: $total_requests" >> "$OUTPUT"

# 2. Count GET and POST requests
get_requests=$(grep '"GET' "$LOG_FILE" | wc -l)
post_requests=$(grep '"POST' "$LOG_FILE" | wc -l)
echo "GET Requests: $get_requests" >> "$OUTPUT"
echo "POST Requests: $post_requests" >> "$OUTPUT"

# 3. Count unique IP addresses
unique_ips=$(awk '{print $1}' "$LOG_FILE" | sort | uniq | wc -l)
echo "Unique IP Addresses: $unique_ips" >> "$OUTPUT"

# 4. Count GET and POST requests per IP
echo "GET and POST requests per IP:" >> "$OUTPUT"
awk '{ip=$1} /GET/ {get[ip]++} /POST/ {post[ip]++}
     END {
       for (ip in get) {
         printf "%s GET: %d POST: %d\n", ip, get[ip], post[ip]+0
       }
     }' "$LOG_FILE" >> "$OUTPUT"

# 5. Count failed requests (4xx and 5xx)
failures=$(awk '$9 ~ /^4|^5/ {count++} END {print count}' "$LOG_FILE")
fail_percent=$(awk -v total="$total_requests" -v fail="$failures" 'BEGIN {printf "%.2f", (fail/total)*100}')
echo "Failed Requests (4xx/5xx): $failures" >> "$OUTPUT"
echo "Failure Percentage: $fail_percent%" >> "$OUTPUT"

# 6. Top 5 Most Active IP addresses
echo "Top 5 Most Active IPs:" >> "$OUTPUT"
top_ips=$(awk '{ips[$1]++} END {for (ip in ips) printf "%s %d\n", ip, ips[ip]}' "$LOG_FILE" | sort -k2 -nr | head -n 5)
echo "$top_ips" >> "$OUTPUT"

# 7. Average requests per day
days=$(awk '{print $4}' "$LOG_FILE" | cut -d: -f1 | cut -d[ -f2 | sort -u | wc -l)
avg_requests=$(awk -v total="$total_requests" -v d="$days" 'BEGIN {printf "%.2f", total/d}')
echo "Average Daily Requests: $avg_requests" >> "$OUTPUT"

# 8. Failures per day
echo "Failures per Day:" >> "$OUTPUT"
awk '$9 ~ /^4|^5/ {date=substr($4, 2, 11); fails[date]++}
     END {
       for (d in fails) {
         printf "%8d %s\n", fails[d], d
       }
     }' "$LOG_FILE" | sort -k2 >> "$OUTPUT"

# 9. Requests per hour
echo "Requests per Hour:" >> "$OUTPUT"
awk -F: '{gsub("\\[","",$2); hour=$2; count[hour]++}
     END {
       for (h=0; h<24; h++) {
         printf "%8d %02d\n", count[h]+0, h
       }
     }' "$LOG_FILE" >> "$OUTPUT"

# 10. Requests per day (Trend)
echo "Requests per Day (Trend):" >> "$OUTPUT"
awk '{print $4}' "$LOG_FILE" | cut -d: -f1 | cut -d[ -f2 | sort | uniq -c >> "$OUTPUT"

# 11. Status code breakdown
echo "Status Code Breakdown:" >> "$OUTPUT"
awk '{codes[$9]++} END {
  for (code in codes) {
    printf "Status %s: %d\n", code, codes[code]
  }
}' "$LOG_FILE" | sort >> "$OUTPUT"

# 12. Top GET and POST users
echo "Top GET and POST Users:" >> "$OUTPUT"
awk '/GET/ {get[$1]++} /POST/ {post[$1]++}
END {
  for (ip in get) if (get[ip] > maxg) {maxg = get[ip]; gip = ip}
  for (ip in post) if (post[ip] > maxp) {maxp = post[ip]; pip = ip}
  print "Top GET IP:", gip, "Requests:", maxg
  print "Top POST IP:", pip, "Requests:", maxp
}' "$LOG_FILE" >> "$OUTPUT"

# 13. Failure requests per hour
echo "Failure Requests per Hour:" >> "$OUTPUT"
awk '$9 ~ /^4|^5/ {
  split($4, time, ":");
  hour = time[2];
  fails[hour]++
} END {
  for (h=0; h<24; h++) {
    printf "Hour %02d: %d failures\n", h, fails[h]+0
  }
}' "$LOG_FILE" >> "$OUTPUT"

# 14. Analysis Suggestions
echo "----- Analysis Suggestions -----" >> "$OUTPUT"
echo "• Investigate peak failure hours shown above to identify server or network issues." >> "$OUTPUT"

# Extract only IPs from top_ips variable
top_ip_list=$(echo "$top_ips" | awk '{print $1}' | paste -sd ', ' -)
echo "• Monitor top IPs ($top_ip_list) for abnormal activity or abuse." >> "$OUTPUT"

echo "• High number of 4xx errors may indicate broken links, unauthorized access, or bot activity." >> "$OUTPUT"
echo "• If 5xx errors appear frequently, review server performance or backend issues." >> "$OUTPUT"
echo "• Consider implementing rate-limiting or CAPTCHA for suspicious IPs." >> "$OUTPUT"
echo "• Review system logs during high-failure periods to find root causes." >> "$OUTPUT"

echo "✅ Analysis saved to $OUTPUT"
