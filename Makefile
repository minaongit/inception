COMPOSE = srcs/docker-compose.yml

help:
	@echo "  make up                      initializes and starts containers"
	@echo "  make down                    deletes containers"
	@echo "  make stop                    pauses containers"
	@echo "  make start                   starts existent containers"
	@echo "  make logs                    show logs"
	@echo "  make ps                      lists all containers"
	@echo "  make clean / fclean / re     clean up the project"
	@echo ""

up:
	mkdir -p $(HOME)/data/mariadb $(HOME)/data/wordpress
	docker compose -f $(COMPOSE) up --build -d

down:
	docker compose -f $(COMPOSE) down

stop:
	docker compose -f $(COMPOSE) stop

start:
	docker compose -f $(COMPOSE) start

logs:
	docker compose -f $(COMPOSE) logs -f

ps:
	docker compose -f $(COMPOSE) ps

clean:
	docker compose -f $(COMPOSE) down --rmi all --volumes

fclean: clean
	sudo rm -rf $(HOME)/data/mariadb/* $(HOME)/data/wordpress/*

re: fclean up
