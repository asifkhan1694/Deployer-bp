#!/bin/bash
# Convenient log viewing script

show_usage() {
    echo "Usage: ./logs.sh [service] [options]"
    echo ""
    echo "Services:"
    echo "  backend    - View backend logs"
    echo "  frontend   - View frontend logs"
    echo "  nginx      - View Nginx logs"
    echo "  mongodb    - View MongoDB logs"
    echo "  all        - View all logs"
    echo ""
    echo "Options:"
    echo "  -f         - Follow logs (tail -f)"
    echo "  -n N       - Show last N lines (default: 50)"
    echo "  -e         - Show error logs only"
    echo ""
    echo "Examples:"
    echo "  ./logs.sh backend -f         # Follow backend logs"
    echo "  ./logs.sh frontend -n 100    # Show last 100 lines"
    echo "  ./logs.sh backend -e         # Show backend errors"
}

SERVICE=${1:-all}
FOLLOW=false
LINES=50
ERRORS_ONLY=false

# Parse options
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        -f)
            FOLLOW=true
            shift
            ;;
        -n)
            LINES=$2
            shift 2
            ;;
        -e)
            ERRORS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

view_log() {
    local log_file=$1
    local label=$2
    
    if [ ! -f "$log_file" ]; then
        echo "Log file not found: $log_file"
        return
    fi
    
    echo "================================================"
    echo "$label"
    echo "================================================"
    
    if [ "$FOLLOW" = true ]; then
        tail -f "$log_file"
    else
        tail -n "$LINES" "$log_file"
    fi
}

case $SERVICE in
    backend)
        if [ "$ERRORS_ONLY" = true ]; then
            view_log "/var/log/supervisor/backend.err.log" "Backend Error Logs"
        else
            view_log "/var/log/supervisor/backend.out.log" "Backend Logs"
        fi
        ;;
    frontend)
        if [ "$ERRORS_ONLY" = true ]; then
            view_log "/var/log/supervisor/frontend.err.log" "Frontend Error Logs"
        else
            view_log "/var/log/supervisor/frontend.out.log" "Frontend Logs"
        fi
        ;;
    nginx)
        if [ "$ERRORS_ONLY" = true ]; then
            view_log "/var/log/nginx/error.log" "Nginx Error Logs"
        else
            view_log "/var/log/nginx/access.log" "Nginx Access Logs"
        fi
        ;;
    mongodb)
        view_log "/var/log/mongodb/mongod.log" "MongoDB Logs"
        ;;
    all)
        echo "Viewing all logs..."
        echo ""
        view_log "/var/log/supervisor/backend.out.log" "Backend Logs"
        echo ""
        view_log "/var/log/supervisor/frontend.out.log" "Frontend Logs"
        echo ""
        view_log "/var/log/nginx/access.log" "Nginx Access Logs"
        ;;
    help)
        show_usage
        ;;
    *)
        echo "Unknown service: $SERVICE"
        show_usage
        exit 1
        ;;
esac
