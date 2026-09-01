# Decisões duradouras

- Cada garagem representa uma única vaga reservável (`capacity = 1`).
- Endereço exato e instruções de acesso ficam em `garage_private_details`, acessíveis apenas ao anfitrião e ao motorista com reserva confirmada/ativa/concluída.
- Reservas são criadas por RPC segura; o cliente não altera status nem valores diretamente.
- Holds `pending_payment` vencem em 15 minutos e devem ser expirados pelo backend usando a função dedicada.
