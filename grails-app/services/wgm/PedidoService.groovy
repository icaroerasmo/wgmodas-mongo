package wgm

import grails.gorm.services.Service

@Service(Pedido)
interface PedidoService {

    Pedido get(Serializable id)

    List<Pedido> list(Map args)

    Long count()

    void delete(Serializable id)

    Pedido save(Pedido pedido)

}