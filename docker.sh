#!/bin/bash

composedir="./composefiles"
composefile="$composedir/build.yml"

# Recuperamos la configuracion de django
eval $(cat ./confs/docker.ini)

if [ $1 = "compose" ]
    then
        # Vaciamos el fichero
        cat /dev/null > "$composefile"

        # Creamos la base
        echo "version: '3.4'" >> "$composefile"
        echo "" >> "$composefile"

        # Insertamos template db segun el tipo de BD
        echo "x-db:" >> "$composefile"
        echo "  &db" >> "$composefile"
        if [ ! -z $DB ] && [ $DB = "internal" ]
            then
                echo "  depends_on:" >> "$composefile"
                echo "    - postgres" >> "$composefile"
        else
            echo "  extra_hosts:" >> "$composefile"
            for host in ${DB//,/ }
            do
                echo "    - '$host:\${EXTERNAL_IP_$host}'" >> "$composefile"
            done
        fi

        # Insertamos resto de templates
        cat $composedir/main-tmpl.yml >> "$composefile"

        for external_volume in ${EXTERNAL_VOLUMES//,/ }
        do
            echo "    - $external_volume" >> "$composefile"
        done

        # Aqui habria que ver si hay mas volumenes y añadirlos

        if [ ! -z $DAPHNE ] && [ $DAPHNE = true ]
            then
                cat $composedir/daphne-tmpl.yml >> "$composefile"
        else
            cat $composedir/django-tmpl.yml >> "$composefile"
        fi

        if [ ! -z $CELERY ] && [ $CELERY = true ]
            then
                cat $composedir/celery-tmpl.yml >> "$composefile"
        fi


        # Comenzamos a insertar los servicios
        echo "" >> "$composefile"
        echo "services:" >> "$composefile"
        echo "" >> "$composefile"

        # Insertamos nginx
        echo "  nginx: *nginx" >> "$composefile"

        # Insertamos daphne o django (excluyentes)
        if [ ! -z $DAPHNE ] && [ $DAPHNE = true ]
            then
                echo "  rabbitmq_daphne: *rabbitmq_daphne" >> "$composefile"
                echo "  django: *daphne" >> "$composefile"
                echo "  worker: *worker" >> "$composefile"
        else
            echo "  django: *django" >> "$composefile"
        fi

        # Insertamos celery si corresponde
        if [ ! -z $CELERY ] && [ $CELERY = true ]
            then
                echo "  rabbitmq_celery: *rabbitmq_celery" >> "$composefile"
                echo "  celery: *celery" >> "$composefile"
        fi

        # Insertamos postgres si corresponde
        if [ ! -z $DB ] && [ $DB = "internal" ]
            then
                echo "  postgres: *postgres" >> "$composefile"
        fi

        # Insertamos networks
        echo "" >> "$composefile"     
        echo "networks:" >> "$composefile"
        echo "  app_network:" >> "$composefile"
        echo "    driver: bridge" >> "$composefile"
        echo "    driver_opts:" >> "$composefile"
        echo "      com.docker.network.enable_ipv6: 'false'" >> "$composefile"
        echo "    ipam:" >> "$composefile"
        echo "      driver: default" >> "$composefile"
        echo "      config:" >> "$composefile"
        echo "        - subnet: 172.\${DOCKER_IP}.0.0/24" >> "$composefile"

else
    cmd="docker-compose -f $composedir/build.yml -p ${PROJECT_NAME}"
    $cmd $@
fi
