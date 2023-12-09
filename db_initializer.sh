#!/bin/bash

# Remember to set the "Format" to LF and not CRLF

# Exits immediately if any errors occur
set -o errexit

#Array containing enviornment variables
# variable expansion ${REQUIRED_ENV_VARS[@]}
readonly REQUIRED_ENV_VARS=(
    "APP_DB_USER",
    "APP_DB_PASS",
    "APP_DB_NAME",
    "POSTGRES_USER",
    "POSTGRES_PASSWORD"
)

#MAIN
# - runs SQL code 
main() {
    echo "running main"
    #check_env_vars_set
    init_user_and_db
    initalize_database_tables
    initalize_database_views
    initalize_database_stored_procedures

    /bin/bash ../x-db_seeder.sh
}

#check all required env vars set
#echos texting explaining which arent set
#and the name of the ones that need to be
check_env_vars_set() {
    for required_env_var in ${REQUIRED_ENV_VARS[@]}; do
        if [[ -z "${!required_env_var}" ]]; then
            echo "ERROR: Enviornment variable '$required_env_var' not set.
            Make sure you have the following enviornment varaibles set:

            ${REQUIRED_ENV_VARS[@]}

            Aborting."

            exit 1
        fi
    done
}

# Initializes already started PostgreSQL
# uses preconfigured POSTGRES_USER user
init_user_and_db() {
    echo "Running init user"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
        CREATE USER $APP_DB_USER WITH PASSWORD '$APP_DB_PASS';
        CREATE DATABASE $APP_DB_NAME;
        GRANT ALL PRIVILEGES ON DATABASE $APP_DB_NAME TO $APP_DB_USER;
EOSQL
}
#\connect $APP_DB_NAME $APP_DB_USER

initalize_database_tables(){
    echo "<----------------    Creating database tables    ---------------->"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;
        CREATE TABLE passengers (
            id uuid PRIMARY KEY,
            name VARCHAR(255),
            email VARCHAR(255),
            photo BYTEA,
            passport_number VARCHAR(255)
        );

        CREATE TABLE planes (
            id uuid PRIMARY KEY,
            max_passengers INT,
            max_baggage_total INT,
            max_baggage_weight INT,
            max_baggage_dimension INT
        );

        CREATE TABLE flights (
            id uuid PRIMARY KEY,
            arrival_time TIMESTAMP,
            departure TIMESTAMP,
            origin VARCHAR(255),
            destination VARCHAR(255),
            plane_id uuid,
            CONSTRAINT fk_flights_planes
                FOREIGN KEY(plane_id)
                    REFERENCES planes(id)
        );        

        CREATE TABLE bookings (
            id uuid PRIMARY KEY,
            created_date TIMESTAMP,
            passenger_id uuid,
            flight_id uuid,
            CONSTRAINT fk_bookings_passengers
                FOREIGN KEY(passenger_id)
                    REFERENCES passengers(id),
            CONSTRAINT fk_bookings_flight
                FOREIGN KEY(flight_id)
                    REFERENCES flights(id)
        );

        CREATE TABLE checkins (
            id uuid PRIMARY KEY,
            booking_id uuid,
            CONSTRAINT fk_checkins_bookings
                FOREIGN KEY(booking_id)
                    REFERENCES bookings(id)
        );

        CREATE TABLE baggage (
            id uuid PRIMARY KEY,
            weight INT,
            booking_id uuid,
            CONSTRAINT fk_baggage_bookings
                FOREIGN KEY(booking_id)
                    REFERENCES bookings(id)
        );

    COMMIT;
EOSQL
}

initalize_database_views(){
    echo "<----------------    Creating db views    ---------------->"
    initalize_boarding_pass_view
    initalize_booking_view
    initalize_checkin_view
    initalize_flight_info_view
    initalize_baggage
}

initalize_boarding_pass_view(){
    echo "Creating boarding_pass_view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_boarding_pass
    AS SELECT
        c.id as checkin_id,
        b.passenger_id,
        b.flight_id

    FROM bookings b
        inner join checkins c
            on b.id = c.booking_id;

    COMMIT;
EOSQL
}

initalize_boarding_pass_view(){
    echo "Creating boarding_pass_view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_boarding_pass
    AS SELECT
        c.id as checkin_id,
        b.passenger_id,
        b.flight_id

    FROM bookings b
        inner join checkins c
            on b.id = c.booking_id;

    COMMIT;
EOSQL
}

initalize_booking_view(){
    echo "Creating booking_view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_booking
    AS SELECT
        book.id,
        p.email,
        p.passport_number,
        bag.weight

    FROM bookings book
        inner join passengers p
            on p.id = book.passenger_id
        inner join baggage bag
            on bag.booking_id = book.id;

    COMMIT;
EOSQL
}

initalize_checkin_view(){
    echo "Creating checkin_view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_checkin
    AS SELECT
        c.id as checkin_id,
        p.email

    FROM bookings b
        inner join passengers p
            on p.id = b.passenger_id
        inner join checkins c
            on b.id = c.booking_id;

    COMMIT;
EOSQL
}

initalize_flight_info_view(){
    echo "Creating flight_info_view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_flight_info
    AS SELECT
        p.id as plane_id,
        p.max_passengers,
        p.max_baggage_weight,
        f.id as flight_id,
        f.arrival_time,
        f.departure,
        f.origin,
        f.destination

    FROM flights f
        inner join planes p
            on p.id = f.plane_id;

    COMMIT;
EOSQL
}

initalize_baggage(){
    echo "Creating baggage view"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace view vw_baggage
    AS SELECT
    f.id as flight_id,
    p.id as passenger_id,
    b.id as booking_id,
    f.destination as destination,
    bag.weight as weight
    FROM bookings b
        inner join flights f
            on b.flight_id = f.id
        inner join passengers p
            on p.id = b.passenger_id
        inner join baggage bag
            on bag.booking_id = b.id;

    COMMIT;
EOSQL
}

initalize_database_stored_procedures(){
    initalize_flight_stored_procedure
    initalize_booking_stored_procedure
    initalize_checkin_stored_procedure
}

# Be careful with the types for the insert statement: uuid and timestamps without timezones
# CALL "sp_insert_flight_data"('d1227f62-a806-4dd6-922d-9be2611c1fc3'::UUID, 420, 9999, 10, 15, 'a9b78c41-c1e7-4ba6-9f9e-032d578d901d'::UUID, '2012-06-13 09:16:16', '2014-06-13 09:16:16', 'CPH', 'Berlin'::VARCHAR(255))
initalize_flight_stored_procedure(){
    echo "Creating flight procedure"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace procedure sp_insert_flight_data(
        plane_id uuid,
        plane_max_passengers INT,
        plane_max_baggage_total INT,
        plane_max_baggage_weight INT,
        plane_max_baggage_dimension INT,
        flight_id uuid,
        flight_arrival_time TIMESTAMP,
        flight_departure TIMESTAMP,
        flight_origin VARCHAR(255),
        flight_destination VARCHAR(255)
        )
    language plpgsql
    as \$\$

    begin
        INSERT INTO planes
        VALUES (plane_id, plane_max_passengers, plane_max_baggage_total, plane_max_baggage_weight, plane_max_baggage_dimension);

        INSERT INTO flights
        VALUES (flight_id, flight_arrival_time, flight_departure, flight_origin, flight_destination, plane_id);
    end;
    \$\$; 

    COMMIT;
EOSQL
}

initalize_booking_stored_procedure(){
    echo "Creating booking procedure"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace procedure sp_insert_booking_data(
        email varchar(255),
        passport_number varchar(255),
        baggage_weight int,
        baggage_id uuid,
        flight_id uuid,
        passenger_id uuid,
        input_booking_id uuid
    )
    language plpgsql
    as \$\$

    begin
        IF NOT EXISTS (SELECT * FROM flights WHERE flights.id = flight_id) THEN
            RETURN;
        END IF;        
        
        INSERT INTO passengers (id, name, email, photo, passport_number)
        VALUES (passenger_id, NULL, email, NULL, passport_number);
        
        INSERT INTO bookings(id, created_date, passenger_id, flight_id)
        VALUES (input_booking_id, NOW()::timestamp, passenger_id, flight_id);

        INSERT INTO baggage(id, weight, booking_id)
        VALUES (baggage_id, baggage_weight, input_booking_id);

    end;
    \$\$; 

    COMMIT;
EOSQL
}

initalize_checkin_stored_procedure(){
    echo "Creating checkin procedure"
    psql -v ON_ERROR_STOP=1 --username "$APP_DB_USER" --dbname "$APP_DB_NAME" <<-EOSQL
    BEGIN;

    create or replace procedure sp_checkin_passenger(
        input_checkin_id uuid,
        input_booking_id uuid
    )
    language plpgsql
    as \$\$  

    begin

        IF EXISTS (SELECT * FROM checkins WHERE checkins.booking_id = input_booking_id) THEN
            RETURN;
        END IF;

        INSERT INTO checkins (id, booking_id)
        VALUES (input_checkin_id, input_booking_id);

    end;
    \$\$; 

    COMMIT;
EOSQL
}

# Runs main routing with env vars passed through command line
main"$@"
