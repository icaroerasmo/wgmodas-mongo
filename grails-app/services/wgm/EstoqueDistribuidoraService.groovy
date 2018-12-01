package wgm

import grails.gorm.services.Service

@Service(EstoqueDistribuidora)
interface EstoqueDistribuidoraService {

    EstoqueDistribuidora get(Serializable id)

    List<EstoqueDistribuidora> list(Map args)

    Long count()

    void delete(Serializable id)

    EstoqueDistribuidora save(EstoqueDistribuidora estoqueDistribuidora)

}