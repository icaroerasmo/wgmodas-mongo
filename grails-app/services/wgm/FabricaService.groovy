package wgm

import grails.gorm.services.Service

@Service(Fabrica)
interface FabricaService {

    Fabrica get(Serializable id)

    List<Fabrica> list(Map args)

    Long count()

    void delete(Serializable id)

    Fabrica save(Fabrica fabrica)

}