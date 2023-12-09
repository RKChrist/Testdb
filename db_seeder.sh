#!/bin/bash

random_string() {
    local len=28
    local str=""
    local chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

    for (( i=0; i<$len; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done

    echo $str
}
random_uuid() {
    local len=36
    local str=""
    local chars="0123456789abcdef"

    # Generate the first group
    for (( i=0; i<8; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done
    str+="-"

    # Generate the second group
    for (( i=0; i<4; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done
    str+="-"

    # Generate the third group
    for (( i=0; i<4; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done
    str+="-"

    # Generate the fourth group
    for (( i=0; i<4; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done
    str+="-"

    # Generate the fifth group
    for (( i=0; i<12; i++ )); do
        str+="${chars:$RANDOM % ${#chars}:1}"
    done

    echo $str
}
seed_database_tables(){
    passengers_ids=()
    checkin_ids=()
    flight_ids=()
    booking_ids=()
    plane_ids=()
    idx=0   #initialize a counter to zero

    for i in {1..150} #some random number range
    do
        passengers_ids[idx]=$(random_uuid)
        checkin_ids[idx]=$(random_uuid)
        flight_ids[idx]=$(random_uuid)
        booking_ids[idx]=$(random_uuid)
        plane_ids[idx]=$(random_uuid)
        idx=$((idx+1)) #increment the counter
    done
    echo "Seeding database tables"
    #Seed planes table
    for id in "${!plane_ids[@]}"; do
        random_max_passengers=$((RANDOM % 1000 + 1))  # Random number between 1 and 1000
        random_max_baggageTotal=$((RANDOM % 2000 + 1))  # Random number between 1 and 2000
        random_max_baggageWeight=$((RANDOM % 50 + 1))  # Random number between 1 and 50
        random_max_baggageDimension=$((RANDOM % 50 + 1))  # Random number between 1 and 50

        seed_planes "${plane_ids[$id]}" "$random_max_passengers" "$random_max_baggageTotal" "$random_max_baggageWeight" "$random_max_baggageDimension"
    done
    echo "Seeding Passengers"
    # Seed passengers
    for id in "${!passengers_ids[@]}"; do
        random_name=$(random_string 10)  # Random name of length 10
        random_email=$(random_string 10)  # Random email of length 10
        random_photo=$(random_string 10)  # Random photo of length 10
        random_passportNumber=$(random_string 10)  # Random passport number of length 10
        echo "$random_name"
        seed_passengers "${passengers_ids[$id]}" "$random_name" "$random_email" "$random_photo" "$random_passportNumber"
    done
    # Seed flights
    for i in {1..149}; do
        days=$((i % 29))
        days=$((days +1))
        echo $days
        hours=$((i % 24))
        if [ $hours < 10 ]; then
            hours="0$hours"
        fi
        random_flight_id="${flight_ids[$i]}"
        givendate="2012-06-13 09:16:16"
        random_arrival_time=$(date +'%Y-%m-%d %H:%M:%S' --date="$givendate")
        random_departure=$(date +'%Y-%m-%d %H:%M:%S' --date="2012-06-$days $hours:16:16")
        random_origin=$(random_string 10)  # Random origin of length 10
        random_destination=$(random_string 10)  # Random destination of length 10
        random_plane_id="${plane_ids[$RANDOM % ${#plane_ids[@]}]}"  # Random plane id

        seed_flights "$random_flight_id" "$random_arrival_time" "$random_departure" "$random_origin" "$random_destination" "$random_plane_id"
    done    

    # seed_bookings
    echo "Seeding Bookings"
    for i in {1..149}; do
        random_booking_id="${booking_ids[$i]}"  # Random booking id of length 28
        random_created_date=$(date +'%Y-%m-%d %H:%M:%S')  # Random created date
        random_passenger_id="${passengers_ids[$i]}"  # Random passenger id
        random_flight_id="${flight_ids[$i]}"  # Random flight id
    
        seed_bookings "$random_booking_id" "$random_created_date" "$random_passenger_id" "$random_flight_id"
    done

    # Seed checkins
    for i in {1..149}; do
        random_booking_id="${booking_ids[$i]}"  # Random booking id of length 28
        random_checkin_id="${checkin_ids[$i]}" # Random checkin id of length 28
        seed_checkins "$random_checkin_id" "$random_booking_id"
    done

    # seed_bagage
    for booking_id in "${!booking_ids[@]}"; do
    # Randomly decide how many baggage items to create for this booking
    num_baggage_items=$((RANDOM % 5))  # Random number between 0 and 4

        for i in $(seq 1 $num_baggage_items); do
            random_baggage_id=$(random_uuid)  # Random baggage id of length 28
            random_weight=$((RANDOM % 50 + 1))  # Random weight between 1 and 50
    
            seed_baggage "$random_baggage_id" "$random_weight" "${booking_ids[$booking_id]}"
        done
    done
}

seed_planes(){
    echo "Seeding Planes"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
    INSERT INTO planes (id, max_passengers, max_baggage_total, max_baggage_weight, max_baggage_dimension)
    VALUES ('$1', '$2', '$3', '$4', '$5');	

    COMMIT;
EOSQL
}

seed_passengers(){
    echo "Seeding Passengers"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
    INSERT INTO passengers (id, name, email, photo, passport_number)
    VALUES ('$1', '$2', '$3', '$4', '$5');	

    COMMIT;
EOSQL

}

seed_checkins(){
    echo "Seeding Checkins"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
    INSERT INTO checkins (id, booking_id)
    VALUES ('$1', '$2');

    COMMIT;
EOSQL
}


seed_flights(){
    echo "Seeding Flights"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
    INSERT INTO flights (id, arrival_time, departure, origin, destination, plane_id)
    VALUES ('$1', '$2', '$3', '$4', '$5', '$6');	

    COMMIT;
EOSQL
}

seed_bookings(){
    echo "Seeding Bookings"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
        INSERT INTO bookings (id, created_date, passenger_id, flight_id)
        VALUES ('$1', '$2', '$3', '$4');	
    COMMIT;
EOSQL
}

seed_baggage(){
    echo "Seeding Baggage"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
    INSERT INTO baggage (id, weight, booking_id)
    VALUES ('$1', '$2', '$3');	

    COMMIT;
EOSQL
}

seed_database_tables